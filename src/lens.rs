//! Lenses: backward passes through nlir programs (v2 §E).
//!
//! A program is a `get`: inputs (bound data, the program's own literals) → output.
//! [`put_program`] is its `put`: given an EDITED output, it returns the edits to the
//! inputs that would produce it, and checks the two lens laws by re-evaluation —
//! **GetPut** (an unedited output implies no edits) and **PutGet** (evaluating the
//! edited inputs reproduces the edited output).
//!
//! Each deterministic construct carries its own put:
//! - `.` / `$get` set the field they read (the canonical lens);
//! - `++` aligns the edited text with the old parts by a character diff and pushes
//!   each part's new text into the expression that produced it (an ambiguous edit
//!   at a boundary goes to data rather than to a template literal);
//! - `$join` splits on its separator; `$trim` restores the trimmed whitespace;
//! - `↦` / `$map` put each item through the mapped form; `$if` puts into the branch
//!   it took; list and dict literals put element-wise;
//! - a form application puts through the form's body, and edits to `$0 $1 …`
//!   become edits to the call's arguments (merged three-way, so separate field
//!   edits to one record combine and clashing ones are reported as conflicts);
//! - a name bound by an earlier statement puts into that statement's right-hand
//!   side; names the program never binds are its INPUTS;
//! - a literal in the program becomes a PROGRAM edit (its AST path is kept).
//!
//! A library can declare isomorphisms in `_inverses` — `_inverses={render=fields}` —
//! and a call to either form then puts through the other directly. That is how a
//! regex-built layout (whose `$sub` has no general inverse) still inverts exactly.
//! Anything else is reported as a stuck edit naming the expression that cannot be
//! inverted, rather than guessed.

use crate::config::{Config, ReduceOp};
use crate::context::Context;
use crate::eval::{EvalError, Evaluator};
use crate::parser::{Expr, Program};
use crate::value::Value;
use serde::Serialize;
use std::collections::{BTreeMap, HashMap};

/// Where a backward edit lands.
#[derive(Debug, Clone, PartialEq, Eq, PartialOrd, Ord)]
enum Root {
    /// A context name: program-bound (resolved further) or an input.
    Name(String),
    /// Positional argument `index` of the put-side call frame `frame`.
    Arg { frame: usize, index: usize },
    /// A literal in the program, at an AST path (statement index, then children).
    Literal(Vec<usize>),
}

/// An edit the backward pass could not push further.
#[derive(Debug, Clone, Serialize)]
pub struct Stuck {
    /// The expression the edit reached.
    pub at: String,
    pub reason: String,
    pub old: String,
    pub new: String,
}

/// One changed leaf of an input.
#[derive(Debug, Clone, Serialize)]
pub struct Change {
    /// `/`-separated path into the input (empty for the whole value).
    pub path: String,
    pub old: serde_json::Value,
    pub new: serde_json::Value,
}

/// An edit to one input or one program literal.
#[derive(Debug, Clone, Serialize)]
pub struct Edit {
    /// `data` (a bound input) or `program` (a literal in the program).
    pub kind: &'static str,
    /// The input's name, or `statement N` for a literal.
    pub target: String,
    /// The literal's AST path (program edits).
    #[serde(skip_serializing_if = "Option::is_none")]
    pub ast_path: Option<Vec<usize>>,
    pub changes: Vec<Change>,
}

/// The result of a backward pass.
#[derive(Debug, Clone, Serialize)]
pub struct PutReport {
    pub output: String,
    pub edited: String,
    pub edits: Vec<Edit>,
    pub stuck: Vec<Stuck>,
    pub conflicts: Vec<String>,
    /// GetPut: putting the unedited output back yields no edits.
    pub get_put: bool,
    /// PutGet: re-evaluating with the edits applied reproduces the edited output
    /// (`None` when edits were stuck, so the law cannot be checked).
    pub put_get: Option<bool>,
    /// The output of that re-evaluation.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub put_get_output: Option<String>,
    /// In llm mode, input changes that pull against each other — across fields, or
    /// within one edited text (merged edits can be textually clean and still
    /// contradict each other).
    #[serde(skip_serializing_if = "Vec::is_empty")]
    pub tensions: Vec<String>,
    /// In llm mode, how fully the re-evaluated output keeps the edited output's
    /// meaning (`≈`, 0–1): model operators are not exact inverses, so PutGet is
    /// judged rather than compared byte for byte.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub put_get_similarity: Option<f64>,
}

#[derive(Default)]
struct Writes {
    map: BTreeMap<Root, (Value, Value)>,
    stuck: Vec<Stuck>,
    conflicts: Vec<String>,
}

impl Writes {
    fn add(&mut self, root: Root, old: Value, new: Value, sep: &str) {
        match self.map.remove(&root) {
            None => {
                self.map.insert(root, (old, new));
            }
            Some((base, prior)) => {
                let merged = match merge3(&base, &prior, &new, sep) {
                    Ok(merged) => merged,
                    Err(at) => {
                        let (x, y) =
                            excerpts(&base.render(sep), &prior.render(sep), &new.render(sep));
                        let at = if at.is_empty() {
                            String::new()
                        } else {
                            format!(" at {at}")
                        };
                        self.conflicts.push(format!(
                            "{} edited two ways{at}: {x:?} vs {y:?}",
                            describe(&root)
                        ));
                        prior
                    }
                };
                self.map.insert(root, (base, merged));
            }
        }
    }

    fn absorb(&mut self, other: Writes, sep: &str) {
        for (root, (old, new)) in other.map {
            self.add(root, old, new, sep);
        }
        self.stuck.extend(other.stuck);
        self.conflicts.extend(other.conflicts);
    }
}

/// The neighbourhood of the first difference between each edit and the base.
fn excerpts(base: &str, a: &str, b: &str) -> (String, String) {
    let around = |text: &str| {
        let prefix = base
            .chars()
            .zip(text.chars())
            .take_while(|(x, y)| x == y)
            .count();
        let chars: Vec<char> = text.chars().collect();
        let start = prefix.saturating_sub(30);
        let end = (prefix + 90).min(chars.len());
        format!(
            "{}{}{}",
            if start > 0 { "…" } else { "" },
            chars[start..end].iter().collect::<String>(),
            if end < chars.len() { "…" } else { "" }
        )
    };
    (around(a), around(b))
}

fn describe(root: &Root) -> String {
    match root {
        Root::Name(name) => format!("${name}"),
        Root::Arg { index, .. } => format!("${index}"),
        Root::Literal(path) => format!("literal at {path:?}"),
    }
}

/// Three-way merge of two edited versions of `base`.
fn merge3(base: &Value, a: &Value, b: &Value, sep: &str) -> Result<Value, String> {
    let same =
        |x: &Value, y: &Value| x.render(sep) == y.render(sep) && x.type_name() == y.type_name();
    if same(a, base) {
        return Ok(b.clone());
    }
    if same(b, base) || same(a, b) {
        return Ok(a.clone());
    }
    match (base, a, b) {
        (Value::Dict(bp), Value::Dict(ap), Value::Dict(cp)) => {
            let mut out = Vec::new();
            let keys: Vec<&String> = bp
                .iter()
                .map(|(k, _)| k)
                .chain(ap.iter().map(|(k, _)| k))
                .chain(cp.iter().map(|(k, _)| k))
                .fold(Vec::new(), |mut acc, k| {
                    if !acc.contains(&k) {
                        acc.push(k);
                    }
                    acc
                });
            for key in keys {
                let get = |pairs: &Vec<(String, Value)>| {
                    pairs.iter().find(|(k, _)| k == key).map(|(_, v)| v.clone())
                };
                let merged = match (get(bp), get(ap), get(cp)) {
                    (Some(x), Some(y), Some(z)) => {
                        merge3(&x, &y, &z, sep).map_err(|at| format!("{key}/{at}"))?
                    }
                    (_, Some(y), None) | (_, None, Some(y)) => y,
                    (None, Some(y), Some(z)) => merge3(&Value::string(String::new()), &y, &z, sep)?,
                    _ => continue,
                };
                out.push((key.clone(), merged));
            }
            Ok(Value::Dict(out))
        }
        (Value::List(bl), Value::List(al), Value::List(cl))
            if bl.len() == al.len() && al.len() == cl.len() =>
        {
            let mut out = Vec::with_capacity(bl.len());
            for (i, ((x, y), z)) in bl.iter().zip(al).zip(cl).enumerate() {
                out.push(merge3(x, y, z, sep).map_err(|at| format!("{i}/{at}"))?);
            }
            Ok(Value::list(out))
        }
        (Value::String(bs), Value::String(a_s), Value::String(b_s)) => merge_text(bs, a_s, b_s)
            .map(Value::string)
            .ok_or_else(String::new),
        _ => Err(String::new()),
    }
}

/// Three-way merge of two edits of one text: both apply when the regions they change
/// do not overlap (a character diff of each against the base); otherwise `None`.
fn merge_text(base: &str, a: &str, b: &str) -> Option<String> {
    use similar::{DiffOp, TextDiff};
    // Changed base ranges (start, end in base chars) with their replacement text.
    fn hunks(base: &str, edited: &str) -> Vec<(usize, usize, String)> {
        let diff = TextDiff::from_chars(base, edited);
        let new_chars: Vec<char> = edited.chars().collect();
        let mut out: Vec<(usize, usize, String)> = Vec::new();
        for op in diff.ops() {
            match *op {
                DiffOp::Equal { .. } => {}
                DiffOp::Delete {
                    old_index, old_len, ..
                } => out.push((old_index, old_index + old_len, String::new())),
                DiffOp::Insert {
                    old_index,
                    new_index,
                    new_len,
                } => {
                    out.push((
                        old_index,
                        old_index,
                        new_chars[new_index..new_index + new_len].iter().collect(),
                    ));
                }
                DiffOp::Replace {
                    old_index,
                    old_len,
                    new_index,
                    new_len,
                } => {
                    out.push((
                        old_index,
                        old_index + old_len,
                        new_chars[new_index..new_index + new_len].iter().collect(),
                    ));
                }
            }
        }
        // Coalesce hunks separated by a short unchanged run, so one edit is one hunk.
        let mut merged: Vec<(usize, usize, String)> = Vec::new();
        let base_chars: Vec<char> = base.chars().collect();
        for (s, e, t) in out {
            match merged.last_mut() {
                Some(last) if s <= last.1 + 3 => {
                    let gap: String = base_chars[last.1..s].iter().collect();
                    last.2 = format!("{}{gap}{t}", last.2);
                    last.1 = e.max(last.1);
                }
                _ => merged.push((s, e, t)),
            }
        }
        merged
    }
    let ha = hunks(base, a);
    let hb = hunks(base, b);
    for (s1, e1, _) in &ha {
        for (s2, e2, _) in &hb {
            let touch = s1.max(s2) <= e1.min(e2) && !(s1 == e1 && s2 == e2 && s1 != s2);
            if touch {
                return None;
            }
        }
    }
    let mut all: Vec<(usize, usize, String)> = ha.into_iter().chain(hb).collect();
    all.sort_by_key(|h| (h.0, h.1));
    let chars: Vec<char> = base.chars().collect();
    let mut out = String::new();
    let mut at = 0;
    for (s, e, t) in all {
        out.extend(&chars[at..s]);
        out.push_str(&t);
        at = e;
    }
    out.extend(&chars[at..]);
    Some(out)
}

/// Give `new` the type of `old` when its text allows (an edited number stays a number).
fn retype(old: &Value, new: Value, sep: &str) -> Value {
    match (old, &new) {
        (Value::Number(_), Value::String(text)) => {
            text.trim().parse::<f64>().map(Value::number).unwrap_or(new)
        }
        (Value::Bool(_), Value::String(text)) => match text.trim() {
            "true" => Value::bool(true),
            "false" => Value::bool(false),
            _ => new,
        },
        _ => {
            let _ = sep;
            new
        }
    }
}

struct Put<'e, 'a> {
    ev: &'e mut Evaluator<'a>,
    mode: crate::Mode,
    program: &'e Program,
    binders: HashMap<String, usize>,
    inverses: BTreeMap<String, String>,
    frames: Vec<usize>,
    next_frame: usize,
    sep: String,
}

fn is_literal(expr: &Expr) -> bool {
    match expr {
        Expr::Bare(_) | Expr::Number(_) => true,
        Expr::Quoted {
            content,
            interpolate,
        } => !*interpolate || !content.contains('$'),
        Expr::Group(inner) => is_literal(inner),
        _ => false,
    }
}

fn child(path: Option<&[usize]>, i: usize) -> Option<Vec<usize>> {
    path.map(|p| {
        let mut out = p.to_vec();
        out.push(i);
        out
    })
}

impl Put<'_, '_> {
    fn stuck(
        &self,
        w: &mut Writes,
        expr: &Expr,
        reason: impl Into<String>,
        old: &Value,
        new: &Value,
    ) {
        w.stuck.push(Stuck {
            at: expr.render(),
            reason: reason.into(),
            old: old.render(&self.sep),
            new: new.render(&self.sep),
        });
    }

    fn op_cfg(&self, sigil: &str) -> Option<crate::config::OperatorConfig> {
        self.ev
            .config_ref()
            .operators
            .values()
            .find(|o| o.op == sigil)
            .cloned()
    }

    fn eval(&mut self, expr: &Expr) -> Result<Value, EvalError> {
        self.ev.eval_expr(expr)
    }

    fn put(
        &mut self,
        expr: &Expr,
        path: Option<&[usize]>,
        new: Value,
        w: &mut Writes,
    ) -> Result<(), EvalError> {
        let old = self.eval(expr)?;
        if old.render(&self.sep) == new.render(&self.sep) {
            return Ok(());
        }
        let new = retype(&old, new, &self.sep);
        match expr {
            Expr::Group(inner) | Expr::Serial(inner) => {
                self.put(inner, child(path, 0).as_deref(), new, w)
            }
            e if is_literal(e) => {
                match path {
                    Some(p) => w.add(Root::Literal(p.to_vec()), old, new, &self.sep),
                    None => self.stuck(
                        w,
                        e,
                        "a literal inside a form the program does not define (prelude or external)",
                        &old,
                        &new,
                    ),
                }
                Ok(())
            }
            Expr::ContextRead(name) => {
                w.add(Root::Name(name.clone()), old, new, &self.sep);
                Ok(())
            }
            Expr::StackIndex(i) if *i >= 0 => {
                match self.frames.last() {
                    Some(&frame) => w.add(
                        Root::Arg {
                            frame,
                            index: *i as usize,
                        },
                        old,
                        new,
                        &self.sep,
                    ),
                    None => self.stuck(w, expr, "a stack read outside any form", &old, &new),
                }
                Ok(())
            }
            Expr::OuterArg { depth, index } => {
                let at = self.frames.len().checked_sub(1 + *depth as usize);
                match at.map(|k| self.frames[k]) {
                    Some(frame) => w.add(
                        Root::Arg {
                            frame,
                            index: *index as usize,
                        },
                        old,
                        new,
                        &self.sep,
                    ),
                    None => self.stuck(
                        w,
                        expr,
                        "an enclosing-form argument with no frame",
                        &old,
                        &new,
                    ),
                }
                Ok(())
            }
            Expr::Assign { value, .. } => self.put(value, child(path, 0).as_deref(), new, w),
            Expr::List(items) => match &new {
                Value::List(new_items) if new_items.len() == items.len() => {
                    for (i, (item, value)) in items.iter().zip(new_items).enumerate() {
                        self.put(item, child(path, i).as_deref(), value.clone(), w)?;
                    }
                    Ok(())
                }
                _ => {
                    self.stuck(w, expr, "a list literal cannot change length", &old, &new);
                    Ok(())
                }
            },
            Expr::Dict(pairs) => match &new {
                Value::Dict(new_pairs) if new_pairs.len() == pairs.len() => {
                    for (i, (key, value)) in pairs.iter().enumerate() {
                        match new_pairs.iter().find(|(k, _)| k == key) {
                            Some((_, v)) => {
                                self.put(value, child(path, i).as_deref(), v.clone(), w)?
                            }
                            None => self.stuck(
                                w,
                                expr,
                                format!("key `{key}` removed from a dict literal"),
                                &old,
                                &new,
                            ),
                        }
                    }
                    Ok(())
                }
                _ => {
                    self.stuck(w, expr, "a dict literal cannot change shape", &old, &new);
                    Ok(())
                }
            },
            Expr::Apply { op, operands, .. } => {
                let cfg = self.op_cfg(op);
                let reduce = cfg.as_ref().and_then(|c| c.reduce);
                let builtin = cfg.as_ref().and_then(|c| c.builtin.clone());
                if reduce == Some(ReduceOp::Concat) {
                    return self.put_concat(expr, operands, path, &old, new, w);
                }
                match builtin.as_deref() {
                    Some("access") if operands.len() == 2 => self.put_access(
                        &operands[0],
                        &operands[1],
                        child(path, 0).as_deref(),
                        new,
                        w,
                    ),
                    Some("map") if operands.len() == 2 => self.put_map(
                        expr,
                        &operands[0],
                        &operands[1],
                        child(path, 0).as_deref(),
                        child(path, 1).as_deref(),
                        &old,
                        new,
                        w,
                    ),
                    _ if self.mode == crate::Mode::Llm
                        && cfg
                            .as_ref()
                            .is_some_and(|c| c.prompt.is_some() && c.reduce.is_none()) =>
                    {
                        let cfg = cfg.expect("checked");
                        self.put_model(expr, op, &cfg, operands, path, &old, new, w)
                    }
                    _ => {
                        let what = if cfg.as_ref().is_some_and(|c| !c.is_deterministic()) {
                            format!(
                                "`{op}` is model-realised: run `nlir put` in llm mode for a model-backed backward pass"
                            )
                        } else {
                            format!("`{op}` has no inverse")
                        };
                        self.stuck(w, expr, what, &old, &new);
                        Ok(())
                    }
                }
            }
            Expr::FormApply { form, args } => {
                self.put_form_apply(expr, form, args, path, &old, new, w)
            }
            _ => {
                self.stuck(w, expr, "no backward pass for this construct", &old, &new);
                Ok(())
            }
        }
    }

    #[allow(clippy::too_many_arguments)]
    fn put_form_apply(
        &mut self,
        expr: &Expr,
        form: &Expr,
        args: &[Expr],
        path: Option<&[usize]>,
        old: &Value,
        new: Value,
        w: &mut Writes,
    ) -> Result<(), EvalError> {
        if let Expr::ContextRead(name) = form {
            let builtin = self.ev.context_ref().get(name).is_none();
            if builtin {
                let arg_path = |i: usize| child(path, i + 1);
                match (name.as_str(), args.len()) {
                    ("get", 2 | 3) => {
                        return self.put_access(&args[0], &args[1], arg_path(0).as_deref(), new, w);
                    }
                    ("join", 2) => {
                        return self.put_join(
                            expr,
                            &args[0],
                            &args[1],
                            arg_path(0).as_deref(),
                            old,
                            new,
                            w,
                        );
                    }
                    ("trim", 1) => return self.put_trim(&args[0], arg_path(0).as_deref(), new, w),
                    ("parse", 1) => {
                        let text = crate::eval::value_to_json_pub(&new).to_string();
                        return self.put(&args[0], arg_path(0).as_deref(), Value::string(text), w);
                    }
                    ("json", 1 | 2) => {
                        let text = new.render(&self.sep);
                        return match serde_json::from_str::<serde_json::Value>(&text) {
                            Ok(json) => {
                                let value =
                                    crate::eval::json_to_value_pub(&json, self.ev.config_ref());
                                self.put(&args[0], arg_path(0).as_deref(), value, w)
                            }
                            Err(error) => {
                                self.stuck(
                                    w,
                                    expr,
                                    format!("the edited text is not JSON ({error})"),
                                    old,
                                    &new,
                                );
                                Ok(())
                            }
                        };
                    }
                    ("map", 2) => {
                        return self.put_map(
                            expr,
                            &args[0],
                            &args[1],
                            arg_path(0).as_deref(),
                            arg_path(1).as_deref(),
                            old,
                            new,
                            w,
                        );
                    }
                    ("sub", 3) | ("lower" | "upper", 1) => {
                        // A normalising rewrite inverts at its fixed points: when it leaves
                        // the edited text unchanged, that text is itself an input that
                        // produces it (e.g. a cleanup that joins lines, on a one-line edit).
                        let mut probe = args.to_vec();
                        probe[0] = Expr::Value(new.clone());
                        let again = self.eval(&Expr::FormApply {
                            form: Box::new(form.clone()),
                            args: probe,
                        })?;
                        if again.render(&self.sep) == new.render(&self.sep) {
                            return self.put(&args[0], arg_path(0).as_deref(), new, w);
                        }
                        self.stuck(
                            w,
                            expr,
                            format!(
                                "`${name}` would rewrite the edited text again, so no input to it gives exactly this text"
                            ),
                            old,
                            &new,
                        );
                        return Ok(());
                    }
                    ("if", 3) => {
                        let cond = self.eval(&args[0])?;
                        let branch = if truthy(&cond) { 1 } else { 2 };
                        return self.put(&args[branch], arg_path(branch).as_deref(), new, w);
                    }
                    _ => {
                        self.stuck(
                            w,
                            expr,
                            format!("the `${name}` builtin has no inverse"),
                            old,
                            &new,
                        );
                        return Ok(());
                    }
                }
            }
        }
        let arg_values = args
            .iter()
            .map(|a| self.eval(a))
            .collect::<Result<Vec<_>, _>>()?;
        let form_path = child(path, 0);
        let new_args = self.put_call(expr, form, form_path.as_deref(), arg_values, old, new, w)?;
        for (i, (arg, value)) in args.iter().zip(new_args).enumerate() {
            if let Some(value) = value {
                self.put(arg, child(path, i + 1).as_deref(), value, w)?;
            }
        }
        Ok(())
    }

    /// Put `new` through a call of `form` on `arg_values`; returns each argument's
    /// new value (`None` = unchanged). Writes to other roots go into `w`.
    #[allow(clippy::too_many_arguments)]
    fn put_call(
        &mut self,
        at: &Expr,
        form: &Expr,
        form_path: Option<&[usize]>,
        arg_values: Vec<Value>,
        old: &Value,
        new: Value,
        w: &mut Writes,
    ) -> Result<Vec<Option<Value>>, EvalError> {
        let n = arg_values.len();
        if let Expr::ContextRead(name) = form
            && let (Some(inverse), 1) = (self.inverses.get(name).cloned(), n)
        {
            let call = Expr::FormApply {
                form: Box::new(Expr::ContextRead(inverse)),
                args: vec![Expr::Value(new)],
            };
            let back = self.eval(&call)?;
            return Ok(vec![Some(back)]);
        }
        let Value::Form(evaluated) = self.eval(form)? else {
            self.stuck(w, at, "applies something that is not a form", old, &new);
            return Ok(vec![None; n]);
        };
        // A form the program defines is put through its body AS WRITTEN in the
        // program (a form read back from the context is re-parsed from source and
        // its tree can differ), so literal edits inside it carry valid AST paths.
        let (body, body_path): (Expr, Option<Vec<usize>>) = match form {
            Expr::ContextRead(name) => match self
                .binders
                .get(name)
                .map(|&k| (k, &self.program.statements[k]))
            {
                Some((k, Expr::Assign { value, .. })) => match value.as_ref() {
                    Expr::Quote(inner) => ((**inner).clone(), Some(vec![k, 0, 0])),
                    _ => (*evaluated, None),
                },
                _ => (*evaluated, None),
            },
            Expr::Quote(inner) => (
                (**inner).clone(),
                form_path.map(|p| {
                    let mut out = p.to_vec();
                    out.push(0);
                    out
                }),
            ),
            _ => (*evaluated, None),
        };
        let frame = self.next_frame;
        self.next_frame += 1;
        self.frames.push(frame);
        self.ev.push_frame(arg_values)?;
        let mut sub = Writes::default();
        let result = self.put(&body, body_path.as_deref(), new, &mut sub);
        self.ev.pop_frame();
        self.frames.pop();
        result?;
        let mut out = vec![None; n];
        let mut rest = Writes {
            stuck: sub.stuck,
            conflicts: sub.conflicts,
            ..Writes::default()
        };
        for (root, (old_v, new_v)) in sub.map {
            match root {
                Root::Arg { frame: f, index } if f == frame && index < n => {
                    out[index] = Some(new_v)
                }
                Root::Arg { frame: f, .. } if f == frame => rest.stuck.push(Stuck {
                    at: at.render(),
                    reason: "an edit reached an argument the call does not pass".into(),
                    old: old_v.render(&self.sep),
                    new: new_v.render(&self.sep),
                }),
                other => rest.map.insert(other, (old_v, new_v)).map_or((), |_| ()),
            }
        }
        w.absorb(rest, &self.sep.clone());
        Ok(out)
    }

    /// A model operator's backward pass: ask a large model for minimal find/replace
    /// patches to the operator's inputs that would turn its output into the edited
    /// output, apply them exactly, and put each changed input further back (so a
    /// patch to an instruction built by `++` lands in the data it was built from).
    #[allow(clippy::too_many_arguments)]
    fn put_model(
        &mut self,
        at: &Expr,
        op: &str,
        cfg: &crate::config::OperatorConfig,
        operands: &[Expr],
        path: Option<&[usize]>,
        old: &Value,
        new: Value,
        w: &mut Writes,
    ) -> Result<(), EvalError> {
        let values = operands
            .iter()
            .map(|o| self.eval(o))
            .collect::<Result<Vec<_>, _>>()?;
        let texts: Vec<String> = values.iter().map(|v| v.render(&self.sep)).collect();
        let what = cfg
            .description
            .as_deref()
            .unwrap_or("a model-realised text operation")
            .trim();
        let mut request = format!(
            "You are computing a BACKWARD pass. The operation `{op}` ({what}) turned the INPUTS below into the OUTPUT. \
A person then edited the OUTPUT into the EDITED OUTPUT. Propose the smallest edits to the INPUTS such that \
performing the same operation on the edited inputs would produce the edited output.\n\n\
Rules:\n\
- Change only what the edit requires; leave every other character of every input exactly as it is.\n\
- Prefer editing the subject matter the output was derived from (the data, facts and conditions it states) \
over the operation's own directions, unless the edit is about form rather than content.\n\
- Each edit replaces ONE exact substring of ONE input: `find` must occur exactly once in that input, so \
include enough surrounding text to make it unique, and `replace` is its new text. Inside JSON data, keep \
the JSON valid.\n\
- If no input edit could produce the change, return an empty list and say why.\n"
        );
        if let Some(back) = cfg.put.as_deref() {
            request.push_str(&format!(
                "- Guidance for reversing this operation: {}\n",
                back.trim()
            ));
        }
        request.push_str("\nReply with JSON only: {\"edits\": [{\"input\": 0, \"find\": \"…\", \"replace\": \"…\"}], \"why\": \"<one sentence>\"}\n");
        for (i, text) in texts.iter().enumerate() {
            request.push_str(&format!("\nINPUT {i}:\n<<<\n{text}\n>>>\n"));
        }
        request.push_str(&format!(
            "\nOUTPUT:\n<<<\n{}\n>>>\n\nEDITED OUTPUT:\n<<<\n{}\n>>>\n",
            old.render(&self.sep),
            new.render(&self.sep)
        ));
        let backward = crate::config::OperatorConfig {
            op: "⟲".into(),
            prompt: Some("%".into()),
            model: Some("large".into()),
            system: Some("generative".into()),
            ..crate::config::OperatorConfig::default()
        };
        let reply = self
            .ev
            .realise_op("⟲", &backward, &[Value::string(request)])?
            .render(&self.sep);
        let parsed = reply
            .find('{')
            .and_then(|start| reply.rfind('}').map(|end| &reply[start..=end]))
            .and_then(|json| serde_json::from_str::<serde_json::Value>(json).ok());
        let Some(parsed) = parsed else {
            let head: String = reply.chars().take(160).collect();
            self.stuck(
                w,
                at,
                format!("the backward request returned no JSON: {head}"),
                old,
                &new,
            );
            return Ok(());
        };
        let edits = parsed
            .get("edits")
            .and_then(serde_json::Value::as_array)
            .cloned()
            .unwrap_or_default();
        if edits.is_empty() {
            let why = parsed
                .get("why")
                .and_then(serde_json::Value::as_str)
                .unwrap_or("no input edit proposed")
                .to_owned();
            self.stuck(
                w,
                at,
                format!("no input edit reproduces this change: {why}"),
                old,
                &new,
            );
            return Ok(());
        }
        let mut patched = texts.clone();
        for edit in edits {
            let index = edit
                .get("input")
                .and_then(serde_json::Value::as_u64)
                .unwrap_or(0) as usize;
            let find = edit
                .get("find")
                .and_then(serde_json::Value::as_str)
                .unwrap_or("")
                .to_owned();
            let replace = edit
                .get("replace")
                .and_then(serde_json::Value::as_str)
                .unwrap_or("")
                .to_owned();
            let applied = match patched.get_mut(index) {
                Some(text) if !find.is_empty() && text.matches(find.as_str()).count() == 1 => {
                    *text = text.replacen(find.as_str(), &replace, 1);
                    true
                }
                _ => false,
            };
            if !applied {
                self.stuck(
                    w,
                    at,
                    format!("a proposed patch did not match input {index} exactly once: {find:?}"),
                    old,
                    &new,
                );
            }
        }
        for (i, (operand, (before, after))) in
            operands.iter().zip(texts.iter().zip(patched)).enumerate()
        {
            if *before != after {
                self.put(operand, child(path, i).as_deref(), Value::string(after), w)?;
            }
        }
        Ok(())
    }

    fn put_access(
        &mut self,
        container: &Expr,
        key: &Expr,
        path: Option<&[usize]>,
        new: Value,
        w: &mut Writes,
    ) -> Result<(), EvalError> {
        let c = self.eval(container)?;
        let k = self.eval(key)?;
        let updated = match (&c, &k) {
            (Value::Dict(pairs), _) => {
                let key = k.render(&self.sep);
                let mut pairs = pairs.clone();
                match pairs.iter_mut().find(|(name, _)| *name == key) {
                    Some(slot) => slot.1 = new,
                    None => pairs.push((key, new)),
                }
                Some(Value::Dict(pairs))
            }
            (Value::List(items), _) => k.render(&self.sep).parse::<i64>().ok().and_then(|i| {
                let len = items.len() as i64;
                let idx = if i < 0 { len + i } else { i };
                (0..len).contains(&idx).then(|| {
                    let mut items = items.clone();
                    items[idx as usize] = new.clone();
                    Value::list(items)
                })
            }),
            _ => None,
        };
        match updated {
            Some(value) => self.put(container, path, value, w),
            None => {
                let old = c.clone();
                self.stuck(w, container, "cannot set a field of this value", &old, &k);
                Ok(())
            }
        }
    }

    #[allow(clippy::too_many_arguments)]
    fn put_map(
        &mut self,
        at: &Expr,
        form: &Expr,
        list: &Expr,
        form_path: Option<&[usize]>,
        list_path: Option<&[usize]>,
        old: &Value,
        new: Value,
        w: &mut Writes,
    ) -> Result<(), EvalError> {
        let Value::List(items) = self.eval(list)? else {
            self.stuck(w, at, "maps over something that is not a list", old, &new);
            return Ok(());
        };
        let Value::List(new_items) = new.clone() else {
            self.stuck(w, at, "a mapped list was edited into a non-list", old, &new);
            return Ok(());
        };
        let Value::List(old_out) = old.clone() else {
            return Ok(());
        };
        let mut updated = items.clone();
        if new_items.len() == items.len() {
            for (i, (item, value)) in items.iter().zip(&new_items).enumerate() {
                if value.render(&self.sep) == old_out[i].render(&self.sep) {
                    continue;
                }
                let back = self.put_call(
                    at,
                    form,
                    form_path,
                    vec![item.clone()],
                    &old_out[i],
                    value.clone(),
                    w,
                )?;
                if let Some(Some(v)) = back.into_iter().next() {
                    updated[i] = v;
                }
            }
        } else {
            // A changed item count needs a declared inverse for the mapped form.
            let inverse = match form {
                Expr::ContextRead(name) => self.inverses.get(name).cloned(),
                _ => None,
            };
            let Some(inverse) = inverse else {
                self.stuck(
                    w,
                    at,
                    "the edit changes the item count of a map whose form has no declared inverse",
                    old,
                    &new,
                );
                return Ok(());
            };
            updated = Vec::with_capacity(new_items.len());
            for value in new_items {
                let call = Expr::FormApply {
                    form: Box::new(Expr::ContextRead(inverse.clone())),
                    args: vec![Expr::Value(value)],
                };
                updated.push(self.eval(&call)?);
            }
        }
        self.put(list, list_path, Value::list(updated), w)
    }

    #[allow(clippy::too_many_arguments)]
    fn put_join(
        &mut self,
        at: &Expr,
        list: &Expr,
        sep_expr: &Expr,
        path: Option<&[usize]>,
        old: &Value,
        new: Value,
        w: &mut Writes,
    ) -> Result<(), EvalError> {
        let sep = self.eval(sep_expr)?.render(&self.sep);
        let text = new.render(&self.sep);
        if sep.is_empty() {
            self.stuck(
                w,
                at,
                "a join with an empty separator cannot be split",
                old,
                &new,
            );
            return Ok(());
        }
        let parts: Vec<Value> = text
            .split(sep.as_str())
            .map(|p| Value::string(p.to_owned()))
            .collect();
        self.put(list, path, Value::list(parts), w)
    }

    fn put_trim(
        &mut self,
        arg: &Expr,
        path: Option<&[usize]>,
        new: Value,
        w: &mut Writes,
    ) -> Result<(), EvalError> {
        let old = self.eval(arg)?.render(&self.sep);
        let lead = &old[..old.len() - old.trim_start().len()];
        let trail = &old[old.trim_end().len()..];
        let text = format!("{lead}{}{trail}", new.render(&self.sep).trim());
        self.put(arg, path, Value::string(text), w)
    }

    /// `a ++ b ++ …` over text: align the edited text with the old parts and give
    /// each part the slice of the new text that replaced it.
    fn put_concat(
        &mut self,
        at: &Expr,
        operands: &[Expr],
        path: Option<&[usize]>,
        old: &Value,
        new: Value,
        w: &mut Writes,
    ) -> Result<(), EvalError> {
        let values = operands
            .iter()
            .map(|o| self.eval(o))
            .collect::<Result<Vec<_>, _>>()?;
        if values
            .iter()
            .any(|v| matches!(v, Value::List(_) | Value::Dict(_)))
        {
            self.stuck(
                w,
                at,
                "`++` over lists or dicts has no text inverse",
                old,
                &new,
            );
            return Ok(());
        }
        let parts: Vec<String> = values.iter().map(|v| v.render(&self.sep)).collect();
        let literal: Vec<bool> = operands.iter().map(is_literal).collect();
        let pieces = split_aligned(&parts, &literal, &new.render(&self.sep));
        for (i, (operand, piece)) in operands.iter().zip(pieces).enumerate() {
            if piece != parts[i] {
                self.put(operand, child(path, i).as_deref(), Value::string(piece), w)?;
            }
        }
        Ok(())
    }
}

fn truthy(value: &Value) -> bool {
    match value {
        Value::Bool(b) => *b,
        Value::Number(n) => *n != 0.0,
        Value::String(s) => !s.is_empty() && s != "false" && s != "0",
        Value::List(items) => !items.is_empty(),
        Value::Dict(pairs) => !pairs.is_empty(),
        Value::Form(_) => true,
    }
}

/// Split `new` into one piece per old part, aligned by a character diff of the old
/// concatenation against `new`. An edit that touches a boundary between a literal
/// and a computed part is given to the computed part (content belongs in data,
/// not in the program's template text).
fn split_aligned(parts: &[String], literal: &[bool], new: &str) -> Vec<String> {
    use similar::{ChangeTag, TextDiff};
    let old: String = parts.concat();
    let old_chars: Vec<char> = old.chars().collect();
    let new_chars: Vec<char> = new.chars().collect();
    // map[i] = position in `new` of old char boundary i (0..=len), choosing for
    // boundaries inside or beside changes per the literal/computed preference.
    let diff = TextDiff::configure()
        .algorithm(similar::Algorithm::Myers)
        .diff_chars(old.as_str(), new);
    // For each old boundary, the new position just before / after any insertion there.
    let mut before = vec![0usize; old_chars.len() + 1];
    let mut after = vec![0usize; old_chars.len() + 1];
    let (mut oi, mut ni) = (0usize, 0usize);
    fn set(o: usize, n: usize, first: bool, before: &mut [usize], after: &mut [usize]) {
        if first {
            before[o] = n;
        }
        after[o] = n;
    }
    set(0, 0, true, &mut before, &mut after);
    let mut last_tag: Option<ChangeTag> = None;
    for change in diff.iter_all_changes() {
        let len = change.value().chars().count();
        match change.tag() {
            ChangeTag::Equal => {
                for _ in 0..len {
                    oi += 1;
                    ni += 1;
                    set(oi, ni, true, &mut before, &mut after);
                }
            }
            ChangeTag::Delete => {
                for _ in 0..len {
                    oi += 1;
                    set(oi, ni, true, &mut before, &mut after);
                }
            }
            ChangeTag::Insert => {
                ni += len;
                after[oi] = ni;
                if last_tag.is_none() && oi == 0 {
                    before[0] = 0;
                }
            }
        }
        last_tag = Some(change.tag());
    }
    // Boundaries between parts.
    let mut cuts = Vec::with_capacity(parts.len() + 1);
    cuts.push(0usize);
    let mut offset = 0usize;
    for (i, part) in parts.iter().enumerate() {
        offset += part.chars().count();
        if i + 1 == parts.len() {
            cuts.push(new_chars.len());
        } else {
            // Insertions at the boundary go to the computed side.
            let left_literal = literal[i];
            let right_literal = literal.get(i + 1).copied().unwrap_or(true);
            let pos = if left_literal && !right_literal {
                before[offset]
            } else {
                after[offset]
            };
            cuts.push(pos.max(*cuts.last().unwrap_or(&0)));
        }
    }
    let _ = old_chars;
    cuts.windows(2)
        .map(|w| {
            new_chars[w[0].min(new_chars.len())..w[1].min(new_chars.len())]
                .iter()
                .collect()
        })
        .collect()
}

/// Ask the large model whether any pair of input changes pulls in opposite
/// directions; returns one line per tension (empty when none, or on failure).
fn check_tensions(
    config: &Config,
    context: &Context,
    cache: &crate::eval::EvaluationCache,
    leaves: &[(String, &Change)],
) -> Vec<String> {
    let mut request = String::from(
        "These edits were derived from one set of changes to a document. Check whether the edited source now \
contradicts itself: two edits that pull in opposite directions (one permits or includes what another forbids \
or excludes, or they make incompatible claims), or a single edited text whose AFTER version says incompatible \
things where its BEFORE version did not. Ignore edits that merely overlap, refine or repeat each other.\n\n\
Reply with JSON only: {\"tensions\": [{\"a\": \"<path>\", \"b\": \"<path, the same path for a text that contradicts itself>\", \"why\": \"<one sentence>\"}]} \
(an empty list when there are none).\n",
    );
    for (path, change) in leaves {
        let text = |v: &serde_json::Value| v.as_str().map_or_else(|| v.to_string(), str::to_owned);
        request.push_str(&format!(
            "\nEDIT {path}\nBEFORE: {}\nAFTER: {}\n",
            text(&change.old),
            text(&change.new)
        ));
    }
    let backward = crate::config::OperatorConfig {
        op: "⟲?".into(),
        prompt: Some("%".into()),
        model: Some("large".into()),
        system: Some("generative".into()),
        ..crate::config::OperatorConfig::default()
    };
    let mut ctx = context.detached();
    let mut ev = Evaluator::new_with_cache(config, &mut ctx, crate::Mode::Llm, cache.clone());
    let Ok(reply) = ev.realise_op("⟲?", &backward, &[Value::string(request)]) else {
        return Vec::new();
    };
    let reply = reply.render("");
    let parsed = reply
        .find('{')
        .and_then(|start| reply.rfind('}').map(|end| &reply[start..=end]))
        .and_then(|json| serde_json::from_str::<serde_json::Value>(json).ok());
    parsed
        .and_then(|p| {
            p.get("tensions")
                .and_then(serde_json::Value::as_array)
                .cloned()
        })
        .unwrap_or_default()
        .iter()
        .map(|t| {
            let s = |k: &str| {
                t.get(k)
                    .and_then(serde_json::Value::as_str)
                    .unwrap_or("?")
                    .to_owned()
            };
            format!("{} ⟷ {}: {}", s("a"), s("b"), s("why"))
        })
        .collect()
}

/// Leaf-level changes between an old and a new input value.
fn changes(old: &Value, new: &Value, sep: &str, path: &str, out: &mut Vec<Change>) {
    if old.render(sep) == new.render(sep) {
        return;
    }
    let join = |k: &str| {
        if path.is_empty() {
            k.to_owned()
        } else {
            format!("{path}/{k}")
        }
    };
    match (old, new) {
        (Value::Dict(a), Value::Dict(b)) => {
            for (k, v) in b {
                match a.iter().find(|(key, _)| key == k) {
                    Some((_, w)) => changes(w, v, sep, &join(k), out),
                    None => out.push(Change {
                        path: join(k),
                        old: serde_json::Value::Null,
                        new: crate::eval::value_to_json_pub(v),
                    }),
                }
            }
        }
        (Value::List(a), Value::List(b)) if a.len() == b.len() => {
            for (i, (x, y)) in a.iter().zip(b).enumerate() {
                changes(x, y, sep, &join(&i.to_string()), out);
            }
        }
        _ => out.push(Change {
            path: path.to_owned(),
            old: crate::eval::value_to_json_pub(old),
            new: crate::eval::value_to_json_pub(new),
        }),
    }
}

/// Replace the expression at `path` (statement index, then child indices).
fn replace_at(program: &mut Program, path: &[usize], replacement: Expr) -> bool {
    fn walk(expr: &mut Expr, path: &[usize], replacement: Expr) -> bool {
        let Some((&i, rest)) = path.split_first() else {
            *expr = replacement;
            return true;
        };
        let next: Option<&mut Expr> = match expr {
            Expr::Group(inner) | Expr::Serial(inner) | Expr::Quote(inner) if i == 0 => Some(inner),
            Expr::Assign { value, .. } if i == 0 => Some(value),
            Expr::List(items) => items.get_mut(i),
            Expr::Dict(pairs) => pairs.get_mut(i).map(|(_, v)| v),
            Expr::Apply { operands, .. } => operands.get_mut(i),
            Expr::FormApply { form, args } => {
                if i == 0 {
                    Some(form)
                } else {
                    args.get_mut(i - 1)
                }
            }
            _ => None,
        };
        next.is_some_and(|e| walk(e, rest, replacement))
    }
    let Some((&k, rest)) = path.split_first() else {
        return false;
    };
    program
        .statements
        .get_mut(k)
        .is_some_and(|stmt| walk(stmt, rest, replacement))
}

/// Run `program` forward (deterministically), then push `edited` back through it:
/// the edits to its inputs and literals that would produce `edited`, with both
/// lens laws checked by re-evaluation.
///
/// # Errors
/// Returns an [`EvalError`] when the forward run fails.
pub fn put_program(
    program: &Program,
    config: &Config,
    context: &Context,
    edited: &str,
) -> Result<PutReport, EvalError> {
    put_program_with(
        program,
        config,
        context,
        edited,
        crate::Mode::Det,
        &crate::eval::EvaluationCache::default(),
    )
}

/// [`put_program_with`] in llm mode where model calls can only be made asynchronously
/// (a browser): run the backward pass against a suspending view of `cache`; when it meets
/// calls the cache has not recorded — the forward run, each backward request, the PutGet
/// re-run, the similarity and tension checks — make them through `realiser`, record them,
/// and run again. Recorded calls replay, so each pass gets further; the pass that needs
/// nothing new returns the report. At most `max_passes` passes.
///
/// # Errors
/// Returns an [`EvalError`] when a call fails, the forward run fails for another reason,
/// or the pass is still waiting on calls after `max_passes`.
pub async fn put_program_async<R: crate::realiser::Realiser>(
    program: &Program,
    config: &Config,
    context: &Context,
    edited: &str,
    cache: &crate::eval::EvaluationCache,
    realiser: &R,
    max_passes: usize,
) -> Result<PutReport, EvalError> {
    for _ in 0..max_passes {
        let view = cache.suspending();
        let result = put_program_with(program, config, context, edited, crate::Mode::Llm, &view);
        // Checks that swallow their own errors (similarity, tensions, a failed PutGet run)
        // still leave their missing calls here, so the pending list decides, not `result`.
        let pending = view.take_pending();
        if pending.is_empty() {
            return result;
        }
        for call in &pending {
            crate::eval::realise_pending(call, config, cache, realiser).await?;
        }
    }
    Err(EvalError::Unsupported(format!(
        "backward pass still waiting on model calls after {max_passes} passes"
    )))
}

/// [`put_program`] in a given mode with a caller's realisation cache: in llm mode,
/// model operators get model-backed backward passes, and the forward run, the
/// backward requests and the PutGet re-run all share `cache` (so unchanged model
/// calls replay rather than re-run).
///
/// # Errors
/// Returns an [`EvalError`] when the forward run fails.
pub fn put_program_with(
    program: &Program,
    config: &Config,
    context: &Context,
    edited: &str,
    mode: crate::Mode,
    cache: &crate::eval::EvaluationCache,
) -> Result<PutReport, EvalError> {
    let mut ctx = context.detached();
    let (output, writes, sep) = {
        let mut ev = Evaluator::new_with_cache(config, &mut ctx, mode, cache.clone());
        let output = ev.run(program)?;
        let sep = ev.separator();
        let mut binders = HashMap::new();
        for (k, stmt) in program.statements.iter().enumerate() {
            if let Expr::Assign { key, .. } = stmt {
                binders.insert(key.clone(), k);
            }
        }
        let mut inverses = BTreeMap::new();
        if let Some(Value::Dict(pairs)) = ev
            .context_ref()
            .get("_inverses")
            .map(|json| crate::eval::json_to_value_pub(json, config))
        {
            for (a, b) in pairs {
                let b = b.render(&sep);
                inverses.insert(a.clone(), b.clone());
                inverses.insert(b, a);
            }
        }
        let mut put = Put {
            ev: &mut ev,
            mode,
            program,
            binders: binders.clone(),
            inverses,
            frames: Vec::new(),
            next_frame: 0,
            sep: sep.clone(),
        };
        let mut w = Writes::default();
        let last = program.statements.len().saturating_sub(1);
        let target = &program.statements[last];
        put.put(
            target,
            Some(&[last]),
            Value::string(edited.to_owned()),
            &mut w,
        )?;
        // Resolve names bound by the program into their statements' right-hand sides.
        for _ in 0..program.statements.len() * 4 + 4 {
            let bound: Vec<Root> = w
                .map
                .keys()
                .filter(|r| matches!(r, Root::Name(n) if binders.contains_key(n)))
                .cloned()
                .collect();
            if bound.is_empty() {
                break;
            }
            for root in bound {
                let Some((_, new)) = w.map.remove(&root) else {
                    continue;
                };
                let Root::Name(name) = &root else { continue };
                let k = binders[name];
                if let Expr::Assign { value, .. } = &program.statements[k] {
                    put.put(value, Some(&[k, 0]), new, &mut w)?;
                }
            }
        }
        (output, w, sep)
    };
    let output_text = output.render(&sep);
    let mut edits = Vec::new();
    let mut patched = program.clone();
    let mut inputs: Vec<(String, Value)> = Vec::new();
    let mut located_all = true;
    for (root, (old, new)) in &writes.map {
        match root {
            Root::Name(name) => {
                let mut cs = Vec::new();
                changes(old, new, &sep, "", &mut cs);
                inputs.push((name.clone(), new.clone()));
                edits.push(Edit {
                    kind: "data",
                    target: name.clone(),
                    ast_path: None,
                    changes: cs,
                });
            }
            Root::Literal(path) => {
                if !replace_at(
                    &mut patched,
                    path,
                    Expr::Quoted {
                        content: new.render(&sep),
                        interpolate: false,
                    },
                ) {
                    located_all = false;
                }
                edits.push(Edit {
                    kind: "program",
                    target: format!("statement {}", path[0] + 1),
                    ast_path: Some(path.clone()),
                    changes: vec![Change {
                        path: String::new(),
                        old: serde_json::Value::String(old.render(&sep)),
                        new: serde_json::Value::String(new.render(&sep)),
                    }],
                });
            }
            Root::Arg { .. } => {}
        }
    }
    let unchanged = output_text == edited;
    let get_put = !unchanged || edits.is_empty();
    let mut stuck = writes.stuck;
    if !located_all {
        stuck.push(Stuck {
            at: "program".into(),
            reason: "a literal edit could not be located in the program".into(),
            old: String::new(),
            new: String::new(),
        });
    }
    let (put_get, put_get_output) = if stuck.is_empty() {
        let mut check = context.detached();
        for (name, value) in &inputs {
            check.set_transient(name.clone(), crate::eval::value_to_json_pub(value));
        }
        let mut ev = Evaluator::new_with_cache(config, &mut check, mode, cache.clone());
        match ev.run(&patched) {
            Ok(value) => {
                let text = value.render(&sep);
                (Some(text == edited), Some(text))
            }
            // A resumable pass must make the missing call, not judge an error message.
            Err(EvalError::Suspended(op)) => return Err(EvalError::Suspended(op)),
            Err(error) => (Some(false), Some(format!("error: {error}"))),
        }
    } else {
        (None, None)
    };
    let put_get_similarity = match (&put_get_output, mode, put_get) {
        (Some(text), crate::Mode::Llm, Some(false)) if !edits.is_empty() => {
            let mut judge_ctx = context.detached();
            let mut ev = Evaluator::new_with_cache(config, &mut judge_ctx, mode, cache.clone());
            let sigil = config
                .operators
                .get("similarity")
                .map(|o| o.op.clone())
                .unwrap_or_else(|| "≈".into());
            let judged = Expr::Apply {
                op: sigil,
                fixity: crate::config::Fixity::Infix,
                operands: vec![
                    Expr::Value(Value::string(edited.to_owned())),
                    Expr::Value(Value::string(text.clone())),
                ],
            };
            ev.eval_expr(&judged)
                .ok()
                .and_then(|v| v.render("").trim().parse::<f64>().ok())
        }
        (_, _, Some(true)) => Some(1.0),
        _ => None,
    };
    let leaves: Vec<(String, &Change)> = edits
        .iter()
        .filter(|e| e.kind == "data")
        .flat_map(|e| {
            e.changes
                .iter()
                .map(move |c| (format!("{}/{}", e.target, c.path), c))
        })
        .collect();
    let tensions = if mode == crate::Mode::Llm && !leaves.is_empty() {
        check_tensions(config, context, cache, &leaves)
    } else {
        Vec::new()
    };
    Ok(PutReport {
        output: output_text,
        tensions,
        edited: edited.to_owned(),
        edits,
        stuck,
        conflicts: writes.conflicts,
        get_put,
        put_get,
        put_get_output,
        put_get_similarity,
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    fn report(src: &str, edited: &str, bind: &[(&str, serde_json::Value)]) -> PutReport {
        let cfg: Config = serde_yaml::from_str(crate::config::EXAMPLE_CONFIG).expect("config");
        let sigils = crate::config::operator_sigils(&cfg);
        let tokens = crate::lexer::tokenize(src, &sigils).expect("lex");
        let program = crate::parser::parse_program(&tokens, &cfg.operators).expect("parse");
        let mut ctx = Context::empty(&cfg.context);
        for (k, v) in bind {
            ctx.set_transient((*k).to_owned(), v.clone());
        }
        put_program(&program, &cfg, &ctx, edited).expect("put")
    }

    #[test]
    fn concat_puts_content_into_data_and_template_into_literals() {
        let rule = serde_json::json!({"id": "R 1", "act": "approve without tests"});
        let src = "'Rule ' ++ $r.id ++ ': reviewers must not ' ++ $r.act ++ '.'";
        // A content edit lands in the bound data, at the field's path.
        let r = report(
            src,
            "Rule R 1: reviewers must not approve without passing tests.",
            &[("r", rule.clone())],
        );
        assert_eq!(r.edits.len(), 1, "{r:?}");
        assert_eq!(r.edits[0].kind, "data");
        assert_eq!(r.edits[0].changes[0].path, "act");
        assert_eq!(r.edits[0].changes[0].new, "approve without passing tests");
        assert_eq!(r.put_get, Some(true));
        // A template edit lands in the program literal.
        let r = report(
            src,
            "Rule R 1: reviewers shall not approve without tests.",
            &[("r", rule.clone())],
        );
        assert_eq!(r.edits[0].kind, "program", "{r:?}");
        assert_eq!(r.put_get, Some(true));
        // GetPut: the unedited output implies no edits.
        let r = report(
            src,
            "Rule R 1: reviewers must not approve without tests.",
            &[("r", rule)],
        );
        assert!(
            r.edits.is_empty() && r.get_put && r.put_get == Some(true),
            "{r:?}"
        );
    }

    #[test]
    fn edits_flow_through_forms_joins_maps_and_statements() {
        let data = serde_json::json!({"items": ["alpha", "beta"], "title": "list"});
        let src = "bullet={'- ' ++ $0}; head={$0.title ++ ':'}; body=$join%($bullet ↦ $d.items, \"\\n\"); $head%$d ++ \"\\n\" ++ $body";
        let r = report(src, "list:\n- alpha\n- gamma", &[("d", data.clone())]);
        assert_eq!(r.edits.len(), 1, "{r:?}");
        assert_eq!(r.edits[0].changes[0].path, "items/1");
        assert_eq!(r.edits[0].changes[0].new, "gamma");
        assert_eq!(r.put_get, Some(true), "{r:?}");
        // Two edits to different fields of one record merge.
        let r = report(src, "LIST:\n- alpha\n- gamma", &[("d", data)]);
        let paths: Vec<_> = r.edits[0].changes.iter().map(|c| c.path.clone()).collect();
        assert_eq!(paths, ["items/1", "title"], "{r:?}");
        assert_eq!(r.put_get, Some(true));
    }

    #[test]
    fn declared_inverses_and_stuck_edits() {
        // $sub has no general inverse, but a declared isomorphism inverts it exactly.
        let data = serde_json::json!({"lines": ["a", "b"]});
        let src = "quote={$sub%($0, '^', '> ')}; unquote={$sub%($0, '^> ', '')}; _inverses={quote=unquote}; $join%($quote ↦ $d.lines, \"\\n\")";
        let r = report(src, "> a\n> c\n> d", &[("d", data.clone())]);
        assert_eq!(r.edits.len(), 1, "{r:?}");
        assert_eq!(r.put_get, Some(true), "{r:?}");
        // Without the declaration the edit is reported as stuck, not guessed.
        let src = "quote={$sub%($0, '^', '> ')}; $join%($quote ↦ $d.lines, \"\\n\")";
        let r = report(src, "> a\n> c", &[("d", data)]);
        assert!(!r.stuck.is_empty(), "{r:?}");
        assert!(r.stuck[0].reason.contains("$sub"), "{r:?}");
        assert_eq!(r.put_get, None);
    }

    #[test]
    fn text_edits_merge_unless_they_overlap() {
        let base = "approve without tests; small diffs do not excuse it";
        let a = "approve without passing tests; small diffs do not excuse it";
        let b = "approve without tests; small diffs never excuse it";
        assert_eq!(
            merge_text(base, a, b).as_deref(),
            Some("approve without passing tests; small diffs never excuse it")
        );
        let c = "approve without any tests; small diffs do not excuse it";
        assert_eq!(
            merge_text(base, a, c),
            None,
            "two edits to one phrase conflict"
        );
    }

    #[test]
    fn model_operator_puts_patch_inputs_and_localise_them() {
        // A fake `=>` that echoes its instruction, and a fake backward model that
        // answers with a fixed patch: exercises the mechanics without a network.
        let yaml = r##"
defaults: { mode: llm, model: { small: echo, medium: echo, large: patcher } }
models:
  echo: { type: command, format: text, command: "printf '%s' \"$NLIR_PROMPT\"" }
  patcher: { type: command, format: text, command: "printf '%s' '{\"edits\":[{\"input\":0,\"find\":\"cats\",\"replace\":\"dogs\"}]}'" }
prompts:
  generative: { text: "" }
operators:
  respond: { op: "=>", arity: 1, fixity: prefix, model: medium, prompt: "%" }
  concat: { op: "++", arity: ">0", fixity: mixfix, priority: 10, operands: any, reduce: concat }
  access: { op: ".", arity: 2, fixity: infix, priority: 19, builtin: access }
"##;
        let cfg = crate::config::parse_str(yaml, std::path::Path::new("t.yaml")).expect("config");
        let sigils = crate::config::operator_sigils(&cfg);
        let src = "=>('Write about ' ++ $d.topic ++ '.')";
        let tokens = crate::lexer::tokenize(src, &sigils).expect("lex");
        let program = crate::parser::parse_program(&tokens, &cfg.operators).expect("parse");
        let mut ctx = Context::empty(&cfg.context);
        ctx.set_transient("d".to_owned(), serde_json::json!({"topic": "cats"}));
        let cache = crate::eval::EvaluationCache::default();
        let forward =
            put_program_with(&program, &cfg, &ctx, "x", crate::Mode::Llm, &cache).expect("put");
        assert!(forward.output.contains("Write about cats."), "{forward:?}");
        let edited = forward.output.replace("cats", "dogs");
        let r =
            put_program_with(&program, &cfg, &ctx, &edited, crate::Mode::Llm, &cache).expect("put");
        assert_eq!(r.edits.len(), 1, "{r:?}");
        assert_eq!(r.edits[0].target, "d");
        assert_eq!(r.edits[0].changes[0].path, "topic");
        assert_eq!(r.edits[0].changes[0].new, "dogs");
        assert_eq!(r.put_get, Some(true), "{r:?}");
    }

    /// Answers like the command models above, but only asynchronously.
    struct AsyncFake {
        calls: std::cell::Cell<usize>,
    }

    impl crate::realiser::Realiser for AsyncFake {
        fn llm<'a>(&'a self, call: &'a crate::llm::LlmCall) -> crate::realiser::RealiseFuture<'a> {
            self.calls.set(self.calls.get() + 1);
            let prompt = call.vars.get("NLIR_PROMPT").cloned().unwrap_or_default();
            let reply = if prompt.contains("BACKWARD pass") {
                r#"{"edits":[{"input":0,"find":"cats","replace":"dogs"}]}"#.to_owned()
            } else if prompt.contains("contradicts itself") {
                r#"{"tensions":[]}"#.to_owned()
            } else {
                prompt
            };
            Box::pin(async move { Ok(reply) })
        }

        fn command<'a>(
            &'a self,
            _command: &'a str,
            _operands: &'a [String],
        ) -> crate::realiser::RealiseFuture<'a> {
            Box::pin(async move { Ok(String::new()) })
        }
    }

    #[test]
    fn backward_pass_resumes_through_an_async_realiser() {
        // No model is callable synchronously (the command models would fail): every
        // call reaches the async realiser through suspend-and-resume, and the result
        // matches the synchronous lens on the same program.
        let yaml = r##"
defaults: { mode: llm, model: { small: none, medium: none, large: none } }
models:
  none: { type: command, format: text, command: "exit 7" }
prompts:
  generative: { text: "" }
operators:
  respond: { op: "=>", arity: 1, fixity: prefix, model: medium, prompt: "%" }
  concat: { op: "++", arity: ">0", fixity: mixfix, priority: 10, operands: any, reduce: concat }
  access: { op: ".", arity: 2, fixity: infix, priority: 19, builtin: access }
"##;
        let cfg = crate::config::parse_str(yaml, std::path::Path::new("t.yaml")).expect("config");
        let sigils = crate::config::operator_sigils(&cfg);
        let src = "=>('Write about ' ++ $d.topic ++ '.')";
        let tokens = crate::lexer::tokenize(src, &sigils).expect("lex");
        let program = crate::parser::parse_program(&tokens, &cfg.operators).expect("parse");
        let mut ctx = Context::empty(&cfg.context);
        ctx.set_transient("d".to_owned(), serde_json::json!({"topic": "cats"}));
        let cache = crate::eval::EvaluationCache::default();
        let fake = AsyncFake {
            calls: std::cell::Cell::new(0),
        };
        let run = |edited: &str| {
            crate::realiser::block_on_ready(put_program_async(
                &program, &cfg, &ctx, edited, &cache, &fake, 16,
            ))
            .expect("put")
        };
        let forward = run("x");
        assert!(forward.output.contains("Write about cats."), "{forward:?}");
        let r = run(&forward.output.replace("cats", "dogs"));
        assert_eq!(r.edits.len(), 1, "{r:?}");
        assert_eq!(r.edits[0].target, "d");
        assert_eq!(r.edits[0].changes[0].path, "topic");
        assert_eq!(r.edits[0].changes[0].new, "dogs");
        assert_eq!(r.put_get, Some(true), "{r:?}");
        let made = fake.calls.get();
        let again = run(&forward.output.replace("cats", "dogs"));
        assert_eq!(again.edits.len(), 1);
        assert_eq!(
            fake.calls.get(),
            made,
            "a repeated backward pass replays every call"
        );
    }

    #[test]
    fn normalising_rewrites_invert_at_their_fixed_points() {
        // `$sub` joining lines: a one-line edit is its own preimage, so it reaches `$d`;
        // an edit the rewrite would change again is stuck, with the reason.
        let r = report(
            "$sub%($d, '\\s*\\n\\s*', ' ')",
            "first line second edited",
            &[("d", serde_json::json!("first line\nsecond"))],
        );
        assert_eq!(r.edits.len(), 1, "{r:?}");
        assert_eq!(r.edits[0].changes[0].new, "first line second edited");
        assert_eq!(r.put_get, Some(true), "{r:?}");
        let r = report(
            "$sub%($d, '\\s*\\n\\s*', ' ')",
            "first line\nsecond edited",
            &[("d", serde_json::json!("first line\nsecond"))],
        );
        assert!(
            r.stuck
                .iter()
                .any(|s| s.reason.contains("rewrite the edited text again")),
            "{r:?}"
        );
    }

    #[test]
    fn model_operators_are_stuck_in_det_mode() {
        let r = report("'note' :: formal", "formal: memo", &[]);
        assert!(
            r.stuck.iter().any(|s| s.reason.contains("model-realised")),
            "{r:?}"
        );
    }
}
