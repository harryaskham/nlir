//! Alternatives for a backward pass (`nlir put --alternatives N`).
//!
//! [`crate::lens::put_program_with`] pushes an edit back through each construct's own put. Some
//! code has no exact put: a selection (`the highest card`), a summary, a comparison, or an `$if`
//! whose branch would have to flip. For those the edit has many possible preimages, or none the
//! structural rules can find. This module looks for them and says how it found each one:
//!
//! - `structural` — the construct-by-construct put (including authored `_puts`), when PutGet holds;
//! - `search` — a breadth-first enumeration of edits to the program's input leaves (det mode,
//!   programs without model calls): numbers take values from the edited output and their
//!   neighbours, strings swap words the program itself uses, booleans flip. Every candidate is
//!   run forward and kept only if it reproduces the edited output exactly. This is a generator of
//!   possible inputs: it reports how many it found within the budget and shows the smallest;
//! - `model` — in llm mode, a large model proposes whole input edits (an arbitrary but plausible
//!   preimage, e.g. a hand of `[5, 6, 7, 8, 9]` rather than `[5, 5, 5, 5, 5]`); each is run forward
//!   and kept only if it reproduces the edit (exactly, or for model outputs by `≈`).
//!
//! `freeze` paths are never edited, which is how a caller asks for a particular explanation
//! ("keep the rules; change the state").

use crate::config::Config;
use crate::context::Context;
use crate::eval::{EvalError, EvaluationCache, Evaluator};
use crate::lens::{PutReport, put_program_with};
use crate::parser::{Expr, Program};
use crate::value::Value;
use serde::Serialize;
use serde_json::Value as Json;
use std::collections::{BTreeMap, BTreeSet};

/// How hard to look, and what not to touch.
#[derive(Debug, Clone)]
pub struct SearchOptions {
    /// How many alternatives to return (the best, smallest first).
    pub alternatives: usize,
    /// The most input leaves one alternative may change.
    pub depth: usize,
    /// The most forward evaluations the search may spend.
    pub budget: usize,
    /// Input paths (`name` or `name/key/0`) that must not change.
    pub freeze: Vec<String>,
    /// For JSON-object outputs: only the fields the edit changed must match; the others are
    /// recomputed (edit the played card; the reason follows).
    pub partial: bool,
}

impl Default for SearchOptions {
    fn default() -> Self {
        Self {
            alternatives: 3,
            depth: 4,
            budget: 100_000,
            freeze: Vec::new(),
            partial: false,
        }
    }
}

/// One changed input leaf.
#[derive(Debug, Clone, Serialize, PartialEq)]
pub struct LeafChange {
    /// `name/key/0` — the input and the path inside it.
    pub path: String,
    pub old: Json,
    pub new: Json,
}

/// One consistent way back: input changes whose forward run reproduces the edited output.
#[derive(Debug, Clone, Serialize)]
pub struct Alternative {
    /// `structural`, `search` or `model`.
    pub source: &'static str,
    pub changes: Vec<LeafChange>,
    /// Program-literal edits (structural alternatives only), as `statement N: old → new`.
    #[serde(skip_serializing_if = "Vec::is_empty")]
    pub program: Vec<String>,
    /// Changed leaves, plus the size of each change (|Δ| for numbers, 1 per swapped word).
    pub size: f64,
    /// What the program outputs with these inputs.
    pub output: String,
    /// `1` for an exact reproduction; `≈` for a model-realised output.
    pub agreement: f64,
    /// The model's one-line reason (model alternatives).
    #[serde(skip_serializing_if = "Option::is_none")]
    pub why: Option<String>,
}

/// The structural report plus every alternative found.
#[derive(Debug, Clone, Serialize)]
pub struct AlternativesReport {
    pub structural: PutReport,
    pub alternatives: Vec<Alternative>,
    /// Distinct minimal preimages the search found (it may be more than shown): no one contains
    /// another, so each is a different explanation, not the same one with an irrelevant extra change.
    pub found: usize,
    /// Forward evaluations the search spent.
    pub evaluated: usize,
    /// Whether the search covered every candidate up to `depth` within the budget.
    pub exhausted: bool,
    /// A plain account of what was tried and what it means.
    pub note: String,
}

/// Find up to `opts.alternatives` consistent backward edits for `edited`.
///
/// # Errors
/// Returns an [`EvalError`] when the forward run of the unedited program fails.
pub fn put_alternatives(
    program: &Program,
    config: &Config,
    context: &Context,
    edited: &str,
    mode: crate::Mode,
    cache: &EvaluationCache,
    opts: &SearchOptions,
) -> Result<AlternativesReport, EvalError> {
    let structural = match put_program_with(program, config, context, edited, mode, cache) {
        Ok(r) => r,
        Err(EvalError::Suspended(op)) => return Err(EvalError::Suspended(op)),
        // the structural pass failed: report it and keep looking by the other routes
        Err(error) => PutReport {
            output: String::new(),
            edited: edited.to_owned(),
            edits: Vec::new(),
            stuck: vec![crate::lens::Stuck {
                at: "program".into(),
                reason: format!("the backward pass failed: {error}"),
                old: String::new(),
                new: String::new(),
            }],
            conflicts: Vec::new(),
            get_put: true,
            put_get: None,
            put_get_output: None,
            tensions: Vec::new(),
            put_get_similarity: None,
        },
    };
    let mut alternatives = Vec::new();
    if structural.put_get == Some(true) {
        let mut changes = Vec::new();
        let mut prog = Vec::new();
        for e in &structural.edits {
            if e.kind == "data" {
                for c in &e.changes {
                    let path = if c.path.is_empty() {
                        e.target.clone()
                    } else {
                        format!("{}/{}", e.target, c.path)
                    };
                    changes.push(LeafChange {
                        path,
                        old: c.old.clone(),
                        new: c.new.clone(),
                    });
                }
            } else {
                for c in &e.changes {
                    prog.push(format!("{}: {} → {}", e.target, c.old, c.new));
                }
            }
        }
        if !frozen_touched(&changes, &opts.freeze) {
            alternatives.push(Alternative {
                source: "structural",
                size: size_of(&changes) + prog.len() as f64,
                changes,
                program: prog,
                output: edited.to_owned(),
                agreement: 1.0,
                why: None,
            });
        }
    }
    let inputs = program_inputs(program, config, context);
    if alternatives.is_empty()
        && opts.partial
        && structural.stuck.is_empty()
        && structural.edits.iter().all(|e| e.kind == "data")
        && !structural.edits.is_empty()
    {
        // a structural put whose edited fields reproduce, with the other fields recomputed
        let mut trial = inputs.clone();
        let mut changes = Vec::new();
        for e in &structural.edits {
            for c in &e.changes {
                let path = if c.path.is_empty() {
                    e.target.clone()
                } else {
                    format!("{}/{}", e.target, c.path)
                };
                let new = c.new.clone();
                if set_leaf(&mut trial, &path, new.clone())
                    || (c.path.is_empty() && {
                        trial.insert(e.target.clone(), new.clone());
                        true
                    })
                {
                    changes.push(LeafChange {
                        path,
                        old: c.old.clone(),
                        new,
                    });
                }
            }
        }
        let old = run_with(program, config, context, cache, &inputs, mode).unwrap_or_default();
        if let Some(out) = run_with(program, config, context, cache, &trial, mode)
            && satisfies(&out, edited, &old, true)
            && !frozen_touched(&changes, &opts.freeze)
        {
            alternatives.push(Alternative {
                source: "structural",
                size: size_of(&changes),
                changes,
                program: Vec::new(),
                output: out,
                agreement: 1.0,
                why: None,
            });
        }
    }
    let model_ops = crate::outline::outline(program, config, &[])
        .statements
        .iter()
        .map(|s| s.model_ops)
        .sum::<usize>();
    let mut found = 0;
    let mut evaluated = 0;
    let mut exhausted = true;
    let mut notes = Vec::new();
    let new_fields = added_fields(program, config, context, cache, edited, &inputs);
    if !new_fields.is_empty() {
        notes.push(format!(
            "the edit adds field(s) the program never outputs ({}): no input can produce them, so the program itself must change",
            new_fields.join(", ")
        ));
    } else if mode == crate::Mode::Det && model_ops == 0 && !inputs.is_empty() {
        let out = search(program, config, context, cache, edited, &inputs, opts);
        found = out.found.len();
        evaluated = out.evaluated;
        exhausted = out.exhausted;
        for (changes, output) in out.found {
            if alternatives
                .iter()
                .any(|a: &Alternative| a.changes == changes)
            {
                continue;
            }
            alternatives.push(Alternative {
                source: "search",
                size: size_of(&changes),
                changes,
                program: Vec::new(),
                output,
                agreement: 1.0,
                why: None,
            });
        }
        notes.push(format!(
            "searched edits of up to {} of {} input leaves, each trying numbers from the edited output, neighbouring values and words the program uses ({} forward runs{}): {} minimal preimage(s) found{}",
            opts.depth,
            leaf_count(&inputs, &opts.freeze),
            evaluated,
            if exhausted { ", all candidates" } else { ", budget reached" },
            found,
            if opts.partial { " (partial: only the edited fields must match)" } else { "" }
        ));
    } else if model_ops > 0 && mode == crate::Mode::Det {
        notes.push("the program calls models, so input search runs in llm mode (`--mode llm`), where a model proposes inputs".into());
    }
    if mode == crate::Mode::Llm && !inputs.is_empty() && new_fields.is_empty() {
        let proposals = model_alternatives(program, config, context, cache, edited, &inputs, opts)?;
        notes.push(format!(
            "{} model proposal(s) reproduced the edit",
            proposals.len()
        ));
        alternatives.extend(proposals);
    }
    alternatives.sort_by(|a, b| {
        b.agreement
            .partial_cmp(&a.agreement)
            .unwrap_or(std::cmp::Ordering::Equal)
            .then(
                a.size
                    .partial_cmp(&b.size)
                    .unwrap_or(std::cmp::Ordering::Equal),
            )
    });
    alternatives.truncate(opts.alternatives.max(1));
    if alternatives.is_empty() && new_fields.is_empty() {
        notes.push(
            "no input edit reproduces this output: it is outside what the program can produce, so the program itself must change"
                .into(),
        );
    }
    Ok(AlternativesReport {
        structural,
        alternatives,
        found,
        evaluated,
        exhausted,
        note: notes.join("; "),
    })
}

/// The program's inputs: names it reads but never binds, present in the context as data.
fn program_inputs(program: &Program, config: &Config, context: &Context) -> BTreeMap<String, Json> {
    let outline = crate::outline::outline(program, config, &[]);
    let bound: BTreeSet<String> = program
        .statements
        .iter()
        .filter_map(|s| match s {
            Expr::Assign { key, .. } => Some(key.clone()),
            _ => None,
        })
        .collect();
    let mut inputs = BTreeMap::new();
    for s in &outline.statements {
        for name in &s.reads {
            if bound.contains(name) || name.starts_with('_') {
                continue;
            }
            if let Some(v) = context.get(name) {
                inputs.insert(name.clone(), v.clone());
            }
        }
    }
    inputs
}

/// One-word quoted string literals in an expression (not template pieces glued with `++`), lowercased:
/// the categorical values a program tests and branches on.
fn single_word_literals(expr: &Expr, out: &mut BTreeSet<String>) {
    match expr {
        // quoted literals only: bare words are field names and keys (`$g.state.turn`), not values
        Expr::Quoted { content, .. } => {
            let ws = words(content);
            if ws.len() == 1
                && ws[0].chars().count() >= 3
                && content.trim().chars().all(char::is_alphabetic)
            {
                out.insert(ws[0].to_lowercase());
            }
        }
        Expr::Group(e) | Expr::Quote(e) | Expr::Serial(e) => single_word_literals(e, out),
        Expr::Assign { value, .. } => single_word_literals(value, out),
        Expr::FormApply { form, args } => {
            single_word_literals(form, out);
            args.iter().for_each(|a| single_word_literals(a, out));
        }
        // template pieces glued with `++` are prose, not values the program decides on
        Expr::Apply { op, operands, .. } if op == "++" => operands
            .iter()
            .filter(|o| !matches!(o, Expr::Quoted { .. }))
            .for_each(|o| single_word_literals(o, out)),
        Expr::Apply { operands, .. } => operands.iter().for_each(|o| single_word_literals(o, out)),
        Expr::List(items) => items.iter().for_each(|i| single_word_literals(i, out)),
        Expr::Dict(pairs) => pairs.iter().for_each(|(_, v)| single_word_literals(v, out)),
        _ => {}
    }
}

/// Keys of a JSON-object edit that the program's current output does not have.
fn added_fields(
    program: &Program,
    config: &Config,
    context: &Context,
    cache: &EvaluationCache,
    edited: &str,
    inputs: &BTreeMap<String, Json>,
) -> Vec<String> {
    let parse = |t: &str| {
        serde_json::from_str::<Json>(t)
            .ok()
            .and_then(|v| v.as_object().cloned())
    };
    let Some(e) = parse(edited) else {
        return Vec::new();
    };
    let mode = crate::Mode::Det;
    let Some(o) = run_with(program, config, context, cache, inputs, mode)
        .as_deref()
        .and_then(parse)
    else {
        return Vec::new();
    };
    e.keys().filter(|k| !o.contains_key(*k)).cloned().collect()
}

/// Leaves of a JSON value, with paths, in a stable order.
fn leaves(prefix: &str, v: &Json, out: &mut Vec<(String, Json)>) {
    match v {
        Json::Object(map) => {
            for (k, x) in map {
                leaves(&format!("{prefix}/{k}"), x, out);
            }
        }
        Json::Array(items) => {
            for (i, x) in items.iter().enumerate() {
                leaves(&format!("{prefix}/{i}"), x, out);
            }
        }
        _ => out.push((prefix.to_owned(), v.clone())),
    }
}

fn frozen(path: &str, freeze: &[String]) -> bool {
    freeze
        .iter()
        .any(|f| path == f || path.starts_with(&format!("{f}/")))
}

fn frozen_touched(changes: &[LeafChange], freeze: &[String]) -> bool {
    changes.iter().any(|c| frozen(&c.path, freeze))
}

fn leaf_count(inputs: &BTreeMap<String, Json>, freeze: &[String]) -> usize {
    let mut all = Vec::new();
    for (name, v) in inputs {
        leaves(name, v, &mut all);
    }
    all.iter().filter(|(p, _)| !frozen(p, freeze)).count()
}

fn size_of(changes: &[LeafChange]) -> f64 {
    changes
        .iter()
        .map(|c| match (c.old.as_f64(), c.new.as_f64()) {
            (Some(a), Some(b)) => 1.0 + (a - b).abs() / 100.0,
            _ => 1.0,
        })
        .sum()
}

/// Set the leaf at `path` (`name/a/0`) inside the inputs.
fn set_leaf(inputs: &mut BTreeMap<String, Json>, path: &str, value: Json) -> bool {
    let mut parts = path.split('/');
    let Some(name) = parts.next() else {
        return false;
    };
    let Some(mut node) = inputs.get_mut(name) else {
        return false;
    };
    for part in parts {
        node = match node {
            Json::Object(map) => match map.get_mut(part) {
                Some(n) => n,
                None => return false,
            },
            Json::Array(items) => match part.parse::<usize>().ok().and_then(|i| items.get_mut(i)) {
                Some(n) => n,
                None => return false,
            },
            _ => return false,
        };
    }
    *node = value;
    true
}

fn words(text: &str) -> Vec<String> {
    let mut out = Vec::new();
    let mut cur = String::new();
    for ch in text.chars() {
        if ch.is_alphabetic() {
            cur.push(ch);
        } else if !cur.is_empty() {
            out.push(std::mem::take(&mut cur));
        }
    }
    if !cur.is_empty() {
        out.push(cur);
    }
    out
}

fn numbers(text: &str) -> Vec<f64> {
    let mut out = Vec::new();
    let mut cur = String::new();
    for ch in text.chars().chain(std::iter::once(' ')) {
        if ch.is_ascii_digit() || (ch == '.' && !cur.is_empty()) || (ch == '-' && cur.is_empty()) {
            cur.push(ch);
        } else {
            if let Ok(n) = cur.trim_end_matches('.').parse::<f64>() {
                out.push(n);
            }
            cur.clear();
        }
    }
    out
}

/// Candidate values for one leaf: numbers from the edited output and the old value's
/// neighbours; strings with one of their words swapped for another word the program uses;
/// booleans flipped.
fn candidates(old: &Json, edited_numbers: &[f64], program_words: &BTreeSet<String>) -> Vec<Json> {
    let mut out: Vec<Json> = Vec::new();
    let mut push = |v: Json| {
        if &v != old && !out.contains(&v) {
            out.push(v);
        }
    };
    match old {
        Json::Number(n) => {
            let x = n.as_f64().unwrap_or(0.0);
            let int = n.is_i64() || n.is_u64();
            let num = |v: f64| {
                if int && v.fract() == 0.0 {
                    Json::from(v as i64)
                } else {
                    serde_json::Number::from_f64(v).map_or(Json::Null, Json::Number)
                }
            };
            for &e in edited_numbers {
                if x < 0.0 || e >= 0.0 {
                    push(num(e));
                }
            }
            push(num(x + 1.0));
            if !(0.0..1.0).contains(&x) {
                push(num(x - 1.0)); // a non-negative input stays non-negative
            }
        }
        Json::Bool(b) => push(Json::Bool(!b)),
        Json::String(s) => {
            let ws = words(s);
            for w in ws
                .iter()
                .filter(|w| program_words.contains(&w.to_lowercase()))
            {
                for v in program_words {
                    if v != &w.to_lowercase() && v.len() >= 3 {
                        push(Json::String(s.replacen(w.as_str(), v, 1)));
                    }
                }
            }
        }
        _ => {}
    }
    out
}

/// Whether a candidate output satisfies the edit: equal to it, or (partial) agreeing on every
/// field the edit changed relative to the old output.
fn satisfies(candidate: &str, edited: &str, old: &str, partial: bool) -> bool {
    if candidate == edited {
        return true;
    }
    if !partial {
        return false;
    }
    let parse = |t: &str| {
        serde_json::from_str::<Json>(t)
            .ok()
            .and_then(|v| v.as_object().cloned())
    };
    let (Some(c), Some(e), Some(o)) = (parse(candidate), parse(edited), parse(old)) else {
        return false;
    };
    let changed: Vec<&String> = e.keys().filter(|k| e.get(*k) != o.get(*k)).collect();
    !changed.is_empty() && changed.iter().all(|k| c.get(*k) == e.get(*k))
}

struct SearchOutcome {
    found: Vec<(Vec<LeafChange>, String)>,
    evaluated: usize,
    exhausted: bool,
}

fn run_with(
    program: &Program,
    config: &Config,
    context: &Context,
    cache: &EvaluationCache,
    inputs: &BTreeMap<String, Json>,
    mode: crate::Mode,
) -> Option<String> {
    let mut ctx = context.detached();
    for (name, value) in inputs {
        ctx.set_transient(name.clone(), value.clone());
    }
    let mut ev = Evaluator::new_with_cache(config, &mut ctx, mode, cache.clone());
    let out = ev.run(program).ok()?;
    let sep = ev.separator();
    Some(out.render(&sep))
}

fn search(
    program: &Program,
    config: &Config,
    context: &Context,
    cache: &EvaluationCache,
    edited: &str,
    inputs: &BTreeMap<String, Json>,
    opts: &SearchOptions,
) -> SearchOutcome {
    // The words a string input may swap: the program's one-word string literals — the categorical
    // values it tests and branches on ('highest', 'lowest') — not its template prose or names.
    let mut program_words = BTreeSet::new();
    for st in &program.statements {
        single_word_literals(st, &mut program_words);
    }
    let edited_numbers = numbers(edited);
    let old_output =
        run_with(program, config, context, cache, inputs, crate::Mode::Det).unwrap_or_default();
    // Prefer swapping the words the edit itself changed (old ⊕ edited) that the program uses; fall back
    // to every program word only when the edit changed none of them.
    let (old_w, new_w): (BTreeSet<String>, BTreeSet<String>) = (
        words(&old_output)
            .into_iter()
            .map(|w| w.to_lowercase())
            .collect(),
        words(edited)
            .into_iter()
            .map(|w| w.to_lowercase())
            .collect(),
    );
    let focused: BTreeSet<String> = old_w
        .symmetric_difference(&new_w)
        .filter(|w| program_words.contains(*w))
        .cloned()
        .collect();
    let program_words = if focused.len() >= 2 {
        focused
    } else {
        program_words
    };
    let _ = &old_output;
    let mut all = Vec::new();
    for (name, v) in inputs {
        leaves(name, v, &mut all);
    }
    let slots: Vec<(String, Json, Vec<Json>)> = all
        .into_iter()
        .filter(|(p, _)| !frozen(p, &opts.freeze))
        .map(|(p, old)| {
            let c = candidates(&old, &edited_numbers, &program_words);
            (p, old, c)
        })
        .filter(|(_, _, c)| !c.is_empty())
        .collect();
    let mut found: Vec<(Vec<LeafChange>, String)> = Vec::new();
    let mut evaluated = 0;
    let mut exhausted = true;
    // Breadth-first by the number of changed leaves: the smallest explanations first.
    'depth: for k in 1..=opts.depth.min(slots.len()) {
        let mut combo: Vec<usize> = (0..k).collect();
        loop {
            // every assignment of candidate values to the k chosen slots
            let sizes: Vec<usize> = combo.iter().map(|&i| slots[i].2.len()).collect();
            let mut pick = vec![0usize; k];
            loop {
                if evaluated >= opts.budget {
                    exhausted = false;
                    break 'depth;
                }
                let mut trial = inputs.clone();
                let mut changes = Vec::with_capacity(k);
                for (j, &i) in combo.iter().enumerate() {
                    let (path, old, cands) = &slots[i];
                    let new = cands[pick[j]].clone();
                    set_leaf(&mut trial, path, new.clone());
                    changes.push(LeafChange {
                        path: path.clone(),
                        old: old.clone(),
                        new,
                    });
                }
                // a change set containing a smaller explanation already found is not minimal: skip it
                let redundant = found
                    .iter()
                    .any(|(f, _)| f.iter().all(|c| changes.contains(c)));
                if !redundant {
                    evaluated += 1;
                    if let Some(out) =
                        run_with(program, config, context, cache, &trial, crate::Mode::Det)
                        && satisfies(&out, edited, &old_output, opts.partial)
                    {
                        found.push((changes, out));
                    }
                }
                // next assignment
                let mut j = k;
                loop {
                    if j == 0 {
                        break;
                    }
                    j -= 1;
                    pick[j] += 1;
                    if pick[j] < sizes[j] {
                        break;
                    }
                    pick[j] = 0;
                    if j == 0 {
                        j = usize::MAX;
                        break;
                    }
                }
                if j == usize::MAX {
                    break;
                }
            }
            // next combination of k slots
            let n = slots.len();
            let mut i = k;
            loop {
                if i == 0 {
                    break;
                }
                i -= 1;
                if combo[i] < n - k + i {
                    combo[i] += 1;
                    for x in i + 1..k {
                        combo[x] = combo[x - 1] + 1;
                    }
                    i = usize::MAX;
                    break;
                }
            }
            if i != usize::MAX {
                break;
            }
        }
        // the smallest explanations are found first; deeper layers add genuinely different ones
        // (supersets of a found explanation are skipped before they are run)
        if found.len() >= opts.alternatives {
            break;
        }
    }
    SearchOutcome {
        found,
        evaluated,
        exhausted,
    }
}

/// Ask a large model for input edits that would make the program produce `edited`; keep
/// those whose forward run reproduces it (exactly, or by `≈` when the program calls models).
fn model_alternatives(
    program: &Program,
    config: &Config,
    context: &Context,
    cache: &EvaluationCache,
    edited: &str,
    inputs: &BTreeMap<String, Json>,
    opts: &SearchOptions,
) -> Result<Vec<Alternative>, EvalError> {
    let source: Vec<String> = program.statements.iter().map(Expr::render).collect();
    let current =
        run_with(program, config, context, cache, inputs, crate::Mode::Llm).unwrap_or_default();
    let mut request = format!(
        "A program maps its INPUTS to an OUTPUT. Someone edited the output. Propose up to {} different, minimal ways to \
change the INPUTS (never the program) so that running the program would produce the EDITED OUTPUT. Prefer plausible \
inputs a person would write, and change as little as possible.{}\n\nReply with JSON only: {{\"alternatives\": \
[{{\"changes\": [{{\"path\": \"<input name>/<key or index>/…\", \"new\": <JSON value>}}], \"why\": \"<one sentence>\"}}]}} — \
paths address leaves of the inputs below, e.g. \"game/state/hand/0\".\n\nPROGRAM:\n<<<\n{}\n>>>\n\nINPUTS:\n<<<\n{}\n>>>\n\nOUTPUT:\n<<<\n{current}\n>>>\n\nEDITED OUTPUT:\n<<<\n{edited}\n>>>\n",
        opts.alternatives.max(1),
        if opts.freeze.is_empty() {
            String::new()
        } else {
            format!(" Do not change these inputs: {}.", opts.freeze.join(", "))
        },
        source.join(";\n"),
        serde_json::to_string_pretty(inputs).unwrap_or_default()
    );
    request.push('\n');
    let op = crate::config::OperatorConfig {
        op: "⟲∃".into(),
        prompt: Some("%".into()),
        model: Some("large".into()),
        system: Some("generative".into()),
        ..crate::config::OperatorConfig::default()
    };
    let mut ctx = context.detached();
    let reply = {
        let mut ev = Evaluator::new_with_cache(config, &mut ctx, crate::Mode::Llm, cache.clone());
        ev.realise_op("⟲∃", &op, &[Value::string(request)])?
            .render("")
    };
    let parsed = reply
        .find('{')
        .and_then(|a| reply.rfind('}').map(|b| &reply[a..=b]))
        .and_then(|j| serde_json::from_str::<Json>(j).ok());
    let mut out = Vec::new();
    for alt in parsed
        .as_ref()
        .and_then(|p| p.get("alternatives"))
        .and_then(Json::as_array)
        .cloned()
        .unwrap_or_default()
    {
        let mut trial = inputs.clone();
        let mut changes = Vec::new();
        let mut ok = true;
        for c in alt
            .get("changes")
            .and_then(Json::as_array)
            .cloned()
            .unwrap_or_default()
        {
            let (Some(path), Some(new)) = (c.get("path").and_then(Json::as_str), c.get("new"))
            else {
                ok = false;
                break;
            };
            let mut probe = Vec::new();
            for (name, v) in inputs {
                leaves(name, v, &mut probe);
            }
            let old = probe
                .iter()
                .find(|(p, _)| p == path)
                .map(|(_, v)| v.clone())
                .unwrap_or(Json::Null);
            if frozen(path, &opts.freeze) || !set_leaf(&mut trial, path, new.clone()) {
                ok = false;
                break;
            }
            changes.push(LeafChange {
                path: path.to_owned(),
                old,
                new: new.clone(),
            });
        }
        if !ok || changes.is_empty() {
            continue;
        }
        let Some(output) = run_with(program, config, context, cache, &trial, crate::Mode::Llm)
        else {
            continue;
        };
        let agreement = if satisfies(&output, edited, &current, opts.partial) {
            1.0
        } else {
            similarity(config, context, cache, edited, &output)
        };
        if agreement >= 0.8 {
            out.push(Alternative {
                source: "model",
                size: size_of(&changes),
                changes,
                program: Vec::new(),
                output,
                agreement,
                why: alt.get("why").and_then(Json::as_str).map(str::to_owned),
            });
        }
    }
    Ok(out)
}

fn similarity(
    config: &Config,
    context: &Context,
    cache: &EvaluationCache,
    a: &str,
    b: &str,
) -> f64 {
    let mut ctx = context.detached();
    let mut ev = Evaluator::new_with_cache(config, &mut ctx, crate::Mode::Llm, cache.clone());
    let sigil = config
        .operators
        .get("similarity")
        .map(|o| o.op.clone())
        .unwrap_or_else(|| "≈".into());
    let judged = Expr::Apply {
        op: sigil,
        fixity: crate::config::Fixity::Infix,
        operands: vec![
            Expr::Value(Value::string(a.to_owned())),
            Expr::Value(Value::string(b.to_owned())),
        ],
    };
    ev.eval_expr(&judged)
        .ok()
        .and_then(|v| v.render("").trim().parse::<f64>().ok())
        .unwrap_or(0.0)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn alts(
        src: &str,
        edited: &str,
        bind: &[(&str, Json)],
        opts: SearchOptions,
    ) -> AlternativesReport {
        let cfg: Config = serde_yaml::from_str(crate::config::EXAMPLE_CONFIG).expect("config");
        let sigils = crate::config::operator_sigils(&cfg);
        let tokens = crate::lexer::tokenize(src, &sigils).expect("lex");
        let program = crate::parser::parse_program(&tokens, &cfg.operators).expect("parse");
        let mut ctx = Context::empty(&cfg.context);
        for (k, v) in bind {
            ctx.set_transient((*k).to_owned(), v.clone());
        }
        put_alternatives(
            &program,
            &cfg,
            &ctx,
            edited,
            crate::Mode::Det,
            &EvaluationCache::default(),
            &opts,
        )
        .expect("alternatives")
    }

    #[test]
    fn a_selection_is_inverted_by_enumerating_inputs() {
        // the highest of a hand: 5 -> 3 needs every card above 3 to come down
        let src = "s = $sort%$hand; $nth%(#$s - 1, $s)";
        let r = alts(
            src,
            "3",
            &[("hand", serde_json::json!([1, 2, 3, 4, 5]))],
            SearchOptions::default(),
        );
        assert!(r.found >= 1, "{}", r.note);
        let best = &r.alternatives[0];
        assert_eq!(best.source, "search");
        assert_eq!(best.changes.len(), 2, "{:?}", best.changes);
        assert!(best.changes.iter().all(|c| c.new == serde_json::json!(3)));
    }

    #[test]
    fn a_branch_flip_and_a_word_swap_are_both_found() {
        // on turn 0 play the highest card, otherwise the lowest; the rule text names which
        let src = "s = $sort%$hand; w = $if%($turn == 0, $rule, 'lowest'); $if%($contains%($w, 'highest'), $nth%(#$s - 1, $s), $nth%(0, $s))";
        let bind = [
            ("hand", serde_json::json!([1, 2, 3, 4, 5])),
            ("turn", serde_json::json!(1)),
            ("rule", serde_json::json!("play the highest card")),
        ];
        let r = alts(
            src,
            "5",
            &bind,
            SearchOptions {
                alternatives: 5,
                ..SearchOptions::default()
            },
        );
        let paths: Vec<String> = r
            .alternatives
            .iter()
            .map(|a| {
                a.changes
                    .iter()
                    .map(|c| c.path.clone())
                    .collect::<Vec<_>>()
                    .join(",")
            })
            .collect();
        assert!(paths.iter().any(|p| p == "turn"), "{paths:?} {}", r.note);
        // freezing the turn forces a different explanation (the hand)
        let r2 = alts(
            src,
            "5",
            &bind,
            SearchOptions {
                alternatives: 5,
                freeze: vec!["turn".into()],
                ..SearchOptions::default()
            },
        );
        assert!(
            r2.alternatives
                .iter()
                .all(|a| a.changes.iter().all(|c| c.path != "turn")),
            "{:?}",
            r2.alternatives
        );
        assert!(!r2.alternatives.is_empty(), "{}", r2.note);
    }

    #[test]
    fn an_output_the_program_cannot_produce_is_reported_as_such() {
        let src = "s = $sort%$hand; $nth%(#$s - 1, $s)";
        let r = alts(
            src,
            "call uno",
            &[("hand", serde_json::json!([1, 2]))],
            SearchOptions::default(),
        );
        assert!(r.alternatives.is_empty());
        assert!(r.note.contains("program itself must change"), "{}", r.note);
    }
}
