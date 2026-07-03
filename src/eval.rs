//! nlir evaluator: the operand-first walk over a parsed [`Program`] that turns
//! an nlir expression into a typed [`Value`] (SPEC §Mental model; §Modes).
//!
//! This is the sequential core (bd-168ef8): children resolve to values before
//! the parent operator runs. DAG parallelism (independent subtrees run
//! concurrently) is a separate bead (exec-graph bd-a32894); here every subtree
//! is evaluated in order, which is a valid serial schedule of the same DAG.
//!
//! For each operator application the evaluator:
//! 1. evaluates every operand (operand-first);
//! 2. **coerces** each operand to the operator's declared operand type
//!    (bd-dd7b5e) — deterministically or with a loud error;
//! 3. **resolves the realisation** (bd-d58371): `command:` / `reduce:` are always
//!    deterministic; otherwise `det` mode uses `template:` / `join:` and `llm`
//!    mode uses `model:` + `prompt:`.
//!
//! Deterministic realisations dispatch to [`crate::realise`]. Grouping `(…)` is
//! preserved in string output (SPEC: parens always win): a grouped operand is
//! rendered with its parentheses when it feeds a string realisation.
//!
//! Not yet wired here (own beads): `command:` realisation (bd-3c1e6d), the LLM
//! realisation path, nullary-pop stack consumption (bd-9aac32), list spread into
//! variadic ops (bd-02a795), and `key=RHS` assignment (bd-c85dee, awaiting the
//! parser `Assign` node). Those return a clear [`EvalError::Unsupported`].

use std::fmt;

use serde_json::Value as Json;

use crate::Mode;
use crate::config::{Arity, Config, OperatorConfig, TypeName};
use crate::context::Context;
use crate::lexer::{self, MessageRole};
use crate::messages::MessageIndex;
use crate::parser::{self, Expr, Program};
use crate::realise::{self, RealiseError};
use crate::stack::Stack;
use crate::value::{CoerceError, Value};

/// An evaluation error.
#[derive(Debug)]
pub enum EvalError {
    /// Tokenisation failed.
    Lex(String),
    /// Parsing failed.
    Parse(String),
    /// An operator sigil with no matching config operator.
    UnknownOperator(String),
    /// A `$name` read of a key not present in the context.
    UnknownContextKey(String),
    /// `$` / `$N` against an empty or too-short stack.
    Stack(String),
    /// A `^` index resolved to no message.
    NoMessage { role: MessageRole, index: i64 },
    /// An operand could not be coerced to the required type.
    Coerce(CoerceError),
    /// A deterministic realisation failed (e.g. div-by-zero).
    Realise(RealiseError),
    /// A `command:` realisation subprocess failed to spawn or exited non-zero.
    Command(String),
    /// A `key=RHS` assignment failed to write through to the context.
    ContextWrite(String),
    /// An `llm`-mode realisation failed (model resolution or backend).
    Llm(String),
    /// The program had no statements, so there is no result value.
    EmptyProgram,
    /// A realisation / feature that has its own not-yet-landed bead.
    Unsupported(String),
}

impl fmt::Display for EvalError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            EvalError::Lex(m) => write!(f, "{m}"),
            EvalError::Parse(m) => write!(f, "{m}"),
            EvalError::UnknownOperator(op) => write!(f, "unknown operator `{op}`"),
            EvalError::UnknownContextKey(k) => write!(f, "unknown context key `{k}`"),
            EvalError::Stack(m) => write!(f, "stack error: {m}"),
            EvalError::NoMessage { role, index } => {
                write!(f, "no message at ^{}{index}", role.suffix())
            }
            EvalError::Coerce(e) => write!(f, "{e}"),
            EvalError::Realise(e) => write!(f, "{e}"),
            EvalError::Command(m) => write!(f, "command realisation failed: {m}"),
            EvalError::ContextWrite(m) => write!(f, "context write failed: {m}"),
            EvalError::Llm(m) => write!(f, "llm realisation failed: {m}"),
            EvalError::EmptyProgram => write!(f, "empty program has no result"),
            EvalError::Unsupported(m) => write!(f, "unsupported: {m}"),
        }
    }
}

impl std::error::Error for EvalError {}

impl From<CoerceError> for EvalError {
    fn from(error: CoerceError) -> Self {
        EvalError::Coerce(error)
    }
}

impl From<RealiseError> for EvalError {
    fn from(error: RealiseError) -> Self {
        EvalError::Realise(error)
    }
}

/// Render a two-line source pointer for a positional diagnostic: the input
/// `expr` on one line and a `^` caret under `position` (a char index) on the
/// next, so lex diagnostics show *where* they failed (bd-1027d5).
fn source_pointer(expr: &str, position: usize) -> String {
    let col = position.min(expr.chars().count());
    format!("  {expr}\n  {}^", " ".repeat(col))
}

/// Evaluate a full nlir program string end-to-end: tokenise → parse → evaluate
/// (SPEC §Mental model). Convenience over [`Evaluator`] for the common path.
///
/// # Errors
/// Returns [`EvalError`] on a lex/parse failure or any evaluation error.
pub fn evaluate(
    expr: &str,
    config: &Config,
    context: &mut Context,
    mode: Mode,
) -> Result<Value, EvalError> {
    let sigils = crate::config::operator_sigils(config);
    let tokens = lexer::tokenize(expr, &sigils).map_err(|error| {
        EvalError::Lex(format!("{error}\n{}", source_pointer(expr, error.position)))
    })?;
    let program = parser::parse_program(&tokens, &config.operators)
        .map_err(|error| EvalError::Parse(error.to_string()))?;
    Evaluator::new(config, context, mode).run(&program)
}

/// The operand-first evaluator: a config + context + a run-scoped stack. The
/// context is mutable so `key=RHS` assignment can write through (SPEC: context
/// writes happen immediately).
pub struct Evaluator<'a> {
    config: &'a Config,
    context: &'a mut Context,
    mode: Mode,
    stack: Stack,
    /// Per-run memoisation of operator realisations keyed by
    /// `(op, mode, model, grouping, operand-texts)` — SPEC §parallelism dedupes
    /// identical subcalls when `_cache` is on (bd-1d078c).
    realise_cache: std::collections::HashMap<String, Value>,
}

impl<'a> Evaluator<'a> {
    /// Build an evaluator over `config` + `context` in `mode`, with a fresh
    /// empty stack.
    #[must_use]
    pub fn new(config: &'a Config, context: &'a mut Context, mode: Mode) -> Self {
        Self {
            config,
            context,
            mode,
            stack: Stack::new(),
            realise_cache: std::collections::HashMap::new(),
        }
    }

    /// Evaluate a whole program: each statement's value is pushed onto the stack
    /// (SPEC: `;` evaluates + pushes); the program result is the final
    /// statement's value.
    ///
    /// # Errors
    /// Returns [`EvalError`] on the first failing statement, or
    /// [`EvalError::EmptyProgram`] when there are no statements.
    pub fn run(&mut self, program: &Program) -> Result<Value, EvalError> {
        let mut last = None;
        for statement in &program.statements {
            let value = self.eval(statement)?;
            self.stack.push(value.clone());
            last = Some(value);
        }
        last.ok_or(EvalError::EmptyProgram)
    }

    /// The active list/message-range separator (`_sep`).
    fn sep(&self) -> String {
        self.context.sep()
    }

    /// Evaluate one expression node to a value (operand-first / bottom-up).
    fn eval(&mut self, expr: &Expr) -> Result<Value, EvalError> {
        match expr {
            Expr::Bare(text) => Ok(Value::string(text.clone())),
            Expr::Quoted {
                content,
                interpolate,
            } => Ok(Value::string(if *interpolate {
                self.context.interpolate(content)
            } else {
                content.clone()
            })),
            Expr::Number(n) => Ok(Value::number(*n)),
            Expr::ContextRead(name) => self.read_context(name),
            Expr::StackPeek => self
                .stack
                .peek()
                .cloned()
                .ok_or_else(|| EvalError::Stack("`$` peek of an empty stack".to_owned())),
            Expr::StackIndex(index) => self
                .stack
                .peek_index(*index)
                .cloned()
                .ok_or_else(|| EvalError::Stack(format!("`${index}` is out of range"))),
            Expr::Message { role, index } => self.eval_message(*role, index),
            // Grouping overrides precedence; its value is the inner value (parens
            // are preserved at the string-realisation boundary, not in the value).
            Expr::Group(inner) => self.eval(inner),
            Expr::List(items) => {
                let values = items
                    .iter()
                    .map(|item| self.eval(item))
                    .collect::<Result<Vec<_>, _>>()?;
                Ok(Value::list(values))
            }
            // A serial marker only constrains scheduling; sequential evaluation
            // already satisfies it (parallelism is exec-graph bd-a32894).
            Expr::Serial(inner) => self.eval(inner),
            // `key=RHS` assignment: evaluate the RHS, write it through to the
            // context immediately (SPEC), and yield the assigned value
            // (bd-c85dee).
            Expr::Assign { key, value } => {
                let assigned = self.eval(value)?;
                self.context
                    .set(key.clone(), value_to_json(&assigned))
                    .map_err(|error| EvalError::ContextWrite(error.to_string()))?;
                Ok(assigned)
            }
            Expr::Apply { op, operands, .. } => self.eval_apply(op, operands),
        }
    }

    /// Read `$name` from the context, converting the stored JSON to a typed
    /// value. A missing key is a loud error.
    fn read_context(&self, name: &str) -> Result<Value, EvalError> {
        self.context
            .get(name)
            .map(json_to_value)
            .ok_or_else(|| EvalError::UnknownContextKey(name.to_owned()))
    }

    /// Evaluate a `^` message index: resolve the index expression to a number,
    /// then read the role-filtered view's message content.
    fn eval_message(&mut self, role: MessageRole, index: &Expr) -> Result<Value, EvalError> {
        let sep = self.sep();
        let index_value = self.eval(index)?;
        let number = index_value
            .coerce(TypeName::Number, &sep)?
            .as_number()
            .ok_or_else(|| EvalError::Unsupported("message index is not a number".to_owned()))?;
        #[allow(clippy::cast_possible_truncation)]
        let i = number.trunc() as i64;
        let view = MessageIndex::new(
            self.context.messages(),
            &self.config.context.messages.views,
            &self.config.context.messages.role_field,
            &self.config.context.messages.content_field,
        );
        view.content_at(role, i)
            .map(Value::string)
            .ok_or(EvalError::NoMessage { role, index: i })
    }

    /// Evaluate an operator application: operand-first eval, operand coercion,
    /// then realisation resolution + dispatch.
    fn eval_apply(&mut self, op: &str, operand_exprs: &[Expr]) -> Result<Value, EvalError> {
        let op_cfg = self
            .config
            .operators
            .values()
            .find(|configured| configured.op == op)
            .ok_or_else(|| EvalError::UnknownOperator(op.to_owned()))?;

        let (operands, grouped) = if operand_exprs.is_empty() {
            // Nullary-pop (bd-9aac32): an operator given no operands consumes
            // from the stack — arity-k pops k, variadic pops all (SPEC §Builtins).
            let popped = match op_cfg.arity {
                Arity::Exact(k) => self.stack.pop_n(k as usize).ok_or_else(|| {
                    EvalError::Stack(format!("`{op}` needs {k} value(s) on the stack to pop"))
                })?,
                Arity::Variadic => self.stack.pop_all(),
            };
            let grouped = vec![false; popped.len()];
            (popped, grouped)
        } else {
            // SPEC: grouping is preserved in string output — remember which
            // operands were parenthesised before we lose that in their values.
            let grouped: Vec<bool> = operand_exprs
                .iter()
                .map(|expr| matches!(expr, Expr::Group(_)))
                .collect();

            // Operand-first (bd-168ef8): resolve every operand to a value.
            let mut operands = Vec::with_capacity(operand_exprs.len());
            for expr in operand_exprs {
                operands.push(self.eval(expr)?);
            }

            // A list operand spreads into a variadic op — `&[a,b,c]` ≡ `a&b&c`
            // (SPEC §Structure; bd-02a795). Non-variadic ops keep the list as one
            // value (it renders via `_sep`).
            if op_cfg.arity == Arity::Variadic {
                spread_lists(operands, grouped)
            } else {
                (operands, grouped)
            }
        };

        let sep = self.sep();
        // Coerce each operand to the operator's operand type (bd-dd7b5e).
        let coerced = operands
            .iter()
            .map(|value| value.coerce(op_cfg.operands, &sep))
            .collect::<Result<Vec<_>, _>>()?;

        self.realise_cached(op, op_cfg, &coerced, &grouped, &sep)
    }

    /// [`Evaluator::realise`] with per-run memoisation (bd-1d078c). When `_cache`
    /// is on (default), identical realisations — same `(op, mode, model,
    /// grouping, operand-texts)` — are computed once and reused, deduping
    /// repeated LLM/command subcalls (SPEC §Execution graph: caching). `_cache`
    /// off bypasses the cache entirely.
    fn realise_cached(
        &mut self,
        op: &str,
        op_cfg: &OperatorConfig,
        operands: &[Value],
        grouped: &[bool],
        sep: &str,
    ) -> Result<Value, EvalError> {
        if !self.context.cache() {
            return self.realise(op, op_cfg, operands, grouped, sep);
        }
        let key = realise_cache_key(
            op,
            self.mode,
            op_cfg.model.as_deref(),
            operands,
            grouped,
            sep,
        );
        if let Some(cached) = self.realise_cache.get(&key) {
            return Ok(cached.clone());
        }
        let result = self.realise(op, op_cfg, operands, grouped, sep)?;
        self.realise_cache.insert(key, result.clone());
        Ok(result)
    }

    /// Resolve + run an operator's realisation (bd-d58371). Order (SPEC §Modes):
    /// `command:` / `reduce:` (always deterministic) → `det` mode `template:` /
    /// `join:` → `llm` mode `model:` + `prompt:`.
    fn realise(
        &self,
        op: &str,
        op_cfg: &OperatorConfig,
        operands: &[Value],
        grouped: &[bool],
        sep: &str,
    ) -> Result<Value, EvalError> {
        if let Some(command) = &op_cfg.command {
            return self.realise_command(command, operands, sep);
        }
        if let Some(reduce_op) = op_cfg.reduce {
            // Numeric reduction ignores grouping (it operates on numbers).
            return Ok(realise::reduce(reduce_op, operands)?);
        }
        match self.mode {
            Mode::Det => {
                let rendered = self.parenthesise_grouped(operands, grouped, sep);
                if let Some(template) = &op_cfg.template {
                    Ok(realise::template(template, &rendered, sep))
                } else if let Some(separator) = &op_cfg.join {
                    Ok(realise::join(&rendered, separator, sep))
                } else {
                    Err(EvalError::Unsupported(format!(
                        "operator `{op}` has no deterministic (template/join/reduce) realisation"
                    )))
                }
            }
            Mode::Llm => {
                // llm realisation (bd-3573aa): resolve the model, fill the
                // prompt from the operands, call the backend via aur-2's
                // llm::realise_llm seam (bd-dc3c72), and wrap the result.
                let Some(prompt) = op_cfg.prompt.as_deref() else {
                    return Err(EvalError::Unsupported(format!(
                        "operator `{op}` has no llm realisation (needs a `prompt:`)"
                    )));
                };
                // Operand text feeds the model's prompt; grouped operands keep
                // their parens (SPEC: preserved in output).
                let rendered = self.parenthesise_grouped(operands, grouped, sep);
                let args: Vec<String> = rendered.iter().map(|value| value.render(sep)).collect();
                crate::llm::realise_llm(
                    op_cfg.model.as_deref(),
                    prompt,
                    &args,
                    self.config,
                    None,
                    |name| std::env::var(name).ok(),
                )
                .map(Value::string)
                .map_err(|error| EvalError::Llm(error.to_string()))
            }
        }
    }

    /// Wrap grouped operands' rendered form in parentheses (SPEC: parens are
    /// preserved in output), leaving ungrouped operands as-is for the string
    /// realisations.
    fn parenthesise_grouped(&self, operands: &[Value], grouped: &[bool], sep: &str) -> Vec<Value> {
        operands
            .iter()
            .zip(grouped)
            .map(|(value, &is_grouped)| {
                if is_grouped {
                    Value::string(format!("({})", value.render(sep)))
                } else {
                    value.clone()
                }
            })
            .collect()
    }

    /// Run a `command:` realisation: operands are exposed to a `bash` subprocess
    /// as the `NLIR_ARGS` array (SPEC `echo` operator), and its stdout is the
    /// result — deterministic in both modes (bd-3c1e6d).
    fn realise_command(
        &self,
        command: &str,
        operands: &[Value],
        sep: &str,
    ) -> Result<Value, EvalError> {
        let args: Vec<String> = operands.iter().map(|value| value.render(sep)).collect();
        let script = format!("{}\n{command}", crate::llm::nlir_args_declaration(&args));
        let output = std::process::Command::new("bash")
            .arg("-c")
            .arg(&script)
            .output()
            .map_err(|error| EvalError::Command(format!("failed to spawn bash: {error}")))?;
        if !output.status.success() {
            let stderr = String::from_utf8_lossy(&output.stderr);
            return Err(EvalError::Command(format!(
                "`{command}` exited with {}: {}",
                output.status,
                stderr.trim()
            )));
        }
        let stdout = String::from_utf8_lossy(&output.stdout);
        // SPEC: stdout is the result; drop a single trailing newline.
        Ok(Value::string(
            stdout.strip_suffix('\n').unwrap_or(&stdout).to_owned(),
        ))
    }
}

/// Spread list operands of a variadic operator into their elements (SPEC:
/// `&[a,b,c]` ≡ `a&b&c`); a spread element is never itself a parenthesised group.
fn spread_lists(operands: Vec<Value>, grouped: Vec<bool>) -> (Vec<Value>, Vec<bool>) {
    let mut out = Vec::with_capacity(operands.len());
    let mut out_grouped = Vec::with_capacity(grouped.len());
    for (value, is_grouped) in operands.into_iter().zip(grouped) {
        match value {
            Value::List(items) => {
                for item in items {
                    out.push(item);
                    out_grouped.push(false);
                }
            }
            other => {
                out.push(other);
                out_grouped.push(is_grouped);
            }
        }
    }
    (out, out_grouped)
}

/// Convert a stored context JSON value to a typed nlir [`Value`].
fn json_to_value(json: &Json) -> Value {
    match json {
        Json::String(text) => Value::string(text.clone()),
        Json::Number(number) => Value::number(number.as_f64().unwrap_or(f64::NAN)),
        Json::Bool(flag) => Value::bool(*flag),
        Json::Array(items) => Value::list(items.iter().map(json_to_value).collect()),
        Json::Null => Value::string(String::new()),
        Json::Object(_) => Value::string(json.to_string()),
    }
}

/// Convert a typed nlir [`Value`] back to a JSON value for context storage
/// (inverse of [`json_to_value`]).
fn value_to_json(value: &Value) -> Json {
    match value {
        Value::String(text) => Json::String(text.clone()),
        Value::Number(number) => {
            serde_json::Number::from_f64(*number).map_or(Json::Null, Json::Number)
        }
        Value::Bool(flag) => Json::Bool(*flag),
        Value::List(items) => Json::Array(items.iter().map(value_to_json).collect()),
    }
}

/// Build the per-run realisation cache key (bd-1d078c): the operator sigil,
/// mode, model alias, grouping, and rendered operand texts uniquely identify a
/// realisation result, so identical subcalls dedupe.
fn realise_cache_key(
    op: &str,
    mode: Mode,
    model: Option<&str>,
    operands: &[Value],
    grouped: &[bool],
    sep: &str,
) -> String {
    let texts: Vec<String> = operands.iter().map(|value| value.render(sep)).collect();
    format!(
        "{op}\u{1f}{}\u{1f}{}\u{1f}{grouped:?}\u{1f}{texts:?}",
        mode.as_str(),
        model.unwrap_or("")
    )
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::config;
    use serde_json::{Map, json};
    use std::path::Path;

    /// The SPEC canonical operator set (the subset exercised deterministically),
    /// including the `_` echo `command:` operator.
    fn config() -> Config {
        let yaml = r##"
operators:
  subject: { op: "#", arity: 1, fixity: prefix, template: "subject of %" }
  not:     { op: "!", arity: 1, fixity: prefix, template: "not %" }
  and:     { op: "&", arity: ">0", fixity: mixfix, join: " and " }
  or:      { op: "|", arity: ">0", fixity: mixfix, join: " or " }
  add:     { op: "+", arity: ">0", fixity: mixfix, operands: number, result: number, reduce: add }
  mul:     { op: "*", arity: ">0", fixity: mixfix, operands: number, result: number, reduce: mul }
  sub:     { op: "-", arity: 2, fixity: infix, operands: number, result: number, reduce: sub }
  div:     { op: "/", arity: 2, fixity: infix, operands: number, result: number, reduce: div }
  pow:     { op: "**", arity: 2, fixity: infix, operands: number, result: number, reduce: pow }
  echo:
    op: "_"
    arity: 2
    fixity: infix
    operands: string
    command: |
      t="${NLIR_ARGS[0]}"; n="${NLIR_ARGS[1]}"; out="$t"
      for i in $(seq 1 $((n-1))); do out="$out $t"; done
      printf '%s' "$out"
  rand:
    op: "~"
    arity: 1
    fixity: prefix
    operands: string
    command: |
      od -An -tx1 -N6 /dev/urandom | tr -d ' '
"##;
        config::parse_str(yaml, Path::new("test-config.yaml")).expect("valid test config")
    }

    /// Evaluate `expr` in det mode over a fresh empty context and render the
    /// result (using the possibly-updated `_sep`).
    fn det(expr: &str) -> String {
        let cfg = config();
        let mut ctx = Context::empty(&cfg.context);
        let value = evaluate(expr, &cfg, &mut ctx, Mode::Det)
            .unwrap_or_else(|e| panic!("eval `{expr}`: {e}"));
        value.render(&ctx.sep())
    }

    #[test]
    fn lex_error_reports_position_with_a_source_caret() {
        // Legible lex diagnostics: no doubled prefix + a source pointer (bd-1027d5).
        let cfg = config();
        let mut ctx = Context::empty(&cfg.context);
        let err = evaluate("\"abc", &cfg, &mut ctx, Mode::Det).unwrap_err();
        let text = err.to_string();
        assert!(
            text.starts_with("lex error at position 0:"),
            "want de-doubled prefix, got: {text}"
        );
        assert!(
            !text.contains("lex error: lex error"),
            "doubled prefix: {text}"
        );
        // The source line + a caret under the offending column.
        assert!(text.contains("\n  \"abc\n"), "source line missing: {text}");
        assert!(text.trim_end().ends_with('^'), "caret missing: {text}");
    }

    #[test]
    fn atoms_evaluate_to_their_values() {
        assert_eq!(det("foo"), "foo");
        assert_eq!(det("'one two'"), "one two"); // SPEC det-quote
        assert_eq!(det("42"), "42");
    }

    #[test]
    fn deterministic_template_and_join() {
        assert_eq!(det("!foo"), "not foo"); // SPEC det-not
        assert_eq!(det("a&b&c"), "a and b and c"); // SPEC det-and
        assert_eq!(det("a|b"), "a or b");
    }

    #[test]
    fn grouping_is_preserved_in_string_output() {
        // SPEC det-group: parens preserved.
        assert_eq!(det("!(a&b)"), "not (a and b)");
    }

    #[test]
    fn numeric_reduce_folds_and_coerces() {
        assert_eq!(det("1+2+3"), "6"); // SPEC num-add
        assert_eq!(det("(1+1)**3"), "8"); // SPEC num-index — group keeps the number
        assert_eq!(det("2*3*4"), "24");
        assert_eq!(det("10-4"), "6");
        assert_eq!(det("9/3"), "3");
    }

    #[test]
    fn semicolon_pushes_and_program_result_is_last_statement() {
        // Each `;` pushes; result is the final statement.
        assert_eq!(det("a;b;c"), "c");
    }

    #[test]
    fn assignment_writes_context_and_yields_value() {
        // SPEC det-assign: k=foo yields "foo", then $k reads it back.
        assert_eq!(det("k=foo;$k"), "foo");
        // The assignment expression itself yields the assigned value.
        assert_eq!(det("k=foo"), "foo");
    }

    #[test]
    fn list_renders_with_sep_and_assignment_can_change_it() {
        // A bare list renders by joining with the active `_sep` (default "\n").
        assert_eq!(det("[a,b]"), "a\nb");
        // SPEC det-sep: set `_sep` to a space, then [a,b] renders "a b".
        assert_eq!(det("_sep=\\ ;[a,b]"), "a b");
    }

    #[test]
    fn list_spreads_into_a_variadic_operator() {
        // SPEC: `[a,b,c]` spreads into a variadic op (a&b&[c,d] ≡ a&b&c&d).
        assert_eq!(det("a&b&[c,d]"), "a and b and c and d");
    }

    #[test]
    fn command_realisation_runs_under_bash() {
        // SPEC det-echo: `xxx_2` → "xxx xxx" via the `_` echo command operator,
        // which runs the `command:` under bash with operands as NLIR_ARGS. The
        // `_` operator lexes again after bd-ebf385.
        assert_eq!(det("xxx_2"), "xxx xxx");
    }

    #[test]
    fn nullary_operator_pops_the_stack() {
        // SPEC: an operator given no operands pops the stack. The parser only
        // produces the bare/nullary form for variadic mixfix ops, which pop all
        // (bd-9aac32).
        assert_eq!(det("a;b;&"), "a and b");
        // A nullary numeric reduce pops + coerces its operands too.
        assert_eq!(det("2;3;+"), "5");
    }

    #[test]
    fn context_reads_resolve_greedily_at_eval_time() {
        // bd-91e573: `$name` reads `context[name]` at eval time, so a read after
        // an assignment reflects the current value (and a later reassignment).
        assert_eq!(det("k=a;$k"), "a");
        assert_eq!(det("k=a;k=b;$k"), "b");
    }

    #[test]
    fn subcall_cache_dedupes_identical_realisations() {
        // bd-1d078c: with `_cache` on (default), two identical realisations (`~x`
        // via a random command) are computed once and reused, so both halves of
        // the join match.
        let out = det("~x&~x");
        let parts: Vec<&str> = out.split(" and ").collect();
        assert_eq!(parts.len(), 2, "expected a two-part join, got {out:?}");
        assert_eq!(
            parts[0], parts[1],
            "identical cached subcalls must return the same value, got {out:?}"
        );
    }

    #[test]
    fn cache_disabled_reruns_each_subcall() {
        // bd-1d078c: with `_cache=false`, identical subcalls are NOT deduped, so
        // two random commands differ. Retry to avoid a rare 6-byte nonce clash.
        let differ = (0..8).any(|_| {
            let out = det("_cache=false;~x&~x");
            matches!(
                out.split(" and ").collect::<Vec<_>>().as_slice(),
                [a, b] if a != b
            )
        });
        assert!(
            differ,
            "with _cache=false, uncached random subcalls should differ across retries"
        );
    }

    #[test]
    fn message_index_reads_role_view() {
        let cfg = config();
        let mut ctx = Context::empty(&cfg.context);
        let mut seed = Map::new();
        seed.insert(
            "_messages".to_owned(),
            json!([
                {"role": "user", "content": "hi"},
                {"role": "assistant", "content": "in rust"}
            ]),
        );
        ctx.merge(seed);
        // SPEC msg test: ^-1 → last assistant message.
        let out = evaluate("^-1", &cfg, &mut ctx, Mode::Det).expect("message eval");
        assert_eq!(out.render(&ctx.sep()), "in rust");
        // Subject-of over the message (prefix template over a `^` index).
        let out = evaluate("#^-1", &cfg, &mut ctx, Mode::Det).expect("subject eval");
        assert_eq!(out.render(&ctx.sep()), "subject of in rust");
    }

    #[test]
    fn context_read_resolves_and_missing_key_errors() {
        let cfg = config();
        let mut ctx = Context::empty(&cfg.context);
        ctx.merge([("k".to_owned(), json!("foo"))].into_iter().collect());
        let out = evaluate("$k", &cfg, &mut ctx, Mode::Det).unwrap();
        assert_eq!(out.render(&ctx.sep()), "foo");
        assert!(matches!(
            evaluate("$missing", &cfg, &mut ctx, Mode::Det),
            Err(EvalError::UnknownContextKey(_))
        ));
    }

    #[test]
    fn div_by_zero_is_a_loud_error() {
        let cfg = config();
        let mut ctx = Context::empty(&cfg.context);
        assert!(matches!(
            evaluate("1/0", &cfg, &mut ctx, Mode::Det),
            Err(EvalError::Realise(_))
        ));
    }

    #[test]
    fn unknown_or_unlexable_operator_fails_loudly() {
        // `~` is not configured; the lexer won't tokenise it — the point is it
        // fails loudly, not silently.
        let cfg = config();
        let mut ctx = Context::empty(&cfg.context);
        assert!(evaluate("a~b", &cfg, &mut ctx, Mode::Det).is_err());
    }

    #[test]
    fn llm_realisation_via_command_model_reaches_the_backend() {
        // llm mode dispatches to the operator's model backend (bd-3573aa). A
        // command-type model keeps it deterministic / offline.
        let yaml = r##"
models:
  cmd: { type: command, format: text, command: "printf 'llm-said-hi'" }
operators:
  ask: { op: "?", arity: 1, fixity: postfix, priority: 0, model: cmd, prompt: "q: %" }
"##;
        let cfg = config::parse_str(yaml, Path::new("llm.yaml")).unwrap();
        let mut ctx = Context::empty(&cfg.context);
        let out = evaluate("x?", &cfg, &mut ctx, Mode::Llm).expect("llm realisation");
        assert_eq!(out.render(&ctx.sep()), "llm-said-hi");
    }

    #[test]
    fn llm_realisation_fills_the_prompt_from_operands() {
        // The operator prompt's `%` is filled with the operand text and reaches
        // the backend via $NLIR_PROMPT.
        let yaml = r##"
models:
  echo: { type: command, format: text, command: "printf '%s' \"$NLIR_PROMPT\"" }
operators:
  neg: { op: "!", arity: 1, fixity: prefix, model: echo, prompt: "negate: %" }
"##;
        let cfg = config::parse_str(yaml, Path::new("llm.yaml")).unwrap();
        let mut ctx = Context::empty(&cfg.context);
        let out = evaluate("!foo", &cfg, &mut ctx, Mode::Llm).expect("llm realisation");
        // aur-2's substitute_operands wraps the single operand in a <text> tag.
        assert_eq!(out.render(&ctx.sep()), "negate: <text>foo</text>");
    }

    #[test]
    fn llm_op_without_prompt_is_unsupported_and_unknown_model_errors() {
        // An op with no `prompt:` has no llm realisation.
        let yaml = r##"
operators:
  bare: { op: "!", arity: 1, fixity: prefix }
  ask:  { op: "?", arity: 1, fixity: postfix, priority: 0, model: nope, prompt: "q: %" }
"##;
        let cfg = config::parse_str(yaml, Path::new("llm.yaml")).unwrap();
        let mut ctx = Context::empty(&cfg.context);
        assert!(matches!(
            evaluate("!x", &cfg, &mut ctx, Mode::Llm),
            Err(EvalError::Unsupported(_))
        ));
        // A prompt with an unknown model is a loud llm error (not silently wrong).
        assert!(matches!(
            evaluate("x?", &cfg, &mut ctx, Mode::Llm),
            Err(EvalError::Llm(_))
        ));
    }
}
