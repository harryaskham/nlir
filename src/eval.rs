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
use crate::config::{Config, OperatorConfig, TypeName};
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
    /// The program had no statements, so there is no result value.
    EmptyProgram,
    /// A realisation / feature that has its own not-yet-landed bead.
    Unsupported(String),
}

impl fmt::Display for EvalError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            EvalError::Lex(m) => write!(f, "lex error: {m}"),
            EvalError::Parse(m) => write!(f, "parse error: {m}"),
            EvalError::UnknownOperator(op) => write!(f, "unknown operator `{op}`"),
            EvalError::UnknownContextKey(k) => write!(f, "unknown context key `{k}`"),
            EvalError::Stack(m) => write!(f, "stack error: {m}"),
            EvalError::NoMessage { role, index } => {
                write!(f, "no message at ^{}{index}", role.suffix())
            }
            EvalError::Coerce(e) => write!(f, "{e}"),
            EvalError::Realise(e) => write!(f, "{e}"),
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

/// Evaluate a full nlir program string end-to-end: tokenise → parse → evaluate
/// (SPEC §Mental model). Convenience over [`Evaluator`] for the common path.
///
/// # Errors
/// Returns [`EvalError`] on a lex/parse failure or any evaluation error.
pub fn evaluate(
    expr: &str,
    config: &Config,
    context: &Context,
    mode: Mode,
) -> Result<Value, EvalError> {
    let sigils = crate::config::operator_sigils(config);
    let tokens =
        lexer::tokenize(expr, &sigils).map_err(|error| EvalError::Lex(error.to_string()))?;
    let program = parser::parse_program(&tokens, &config.operators)
        .map_err(|error| EvalError::Parse(error.to_string()))?;
    Evaluator::new(config, context, mode).run(&program)
}

/// The operand-first evaluator: a config + context + a run-scoped stack.
pub struct Evaluator<'a> {
    config: &'a Config,
    context: &'a Context,
    mode: Mode,
    stack: Stack,
}

impl<'a> Evaluator<'a> {
    /// Build an evaluator over `config` + `context` in `mode`, with a fresh
    /// empty stack.
    #[must_use]
    pub fn new(config: &'a Config, context: &'a Context, mode: Mode) -> Self {
        Self {
            config,
            context,
            mode,
            stack: Stack::new(),
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
            Expr::Bare(text) | Expr::Quoted(text) => Ok(Value::string(text.clone())),
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
            // `key=RHS` context write-through is its own bead (bd-c85dee) and needs
            // a mutable context; the parser node (bd-4c3498) is landed, the eval
            // side lands next.
            Expr::Assign { key, .. } => Err(EvalError::Unsupported(format!(
                "assignment `{key}=…` (bd-c85dee) not yet wired"
            ))),
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

        // SPEC: grouping is preserved in string output — remember which operands
        // were parenthesised before we lose that in their values.
        let grouped: Vec<bool> = operand_exprs
            .iter()
            .map(|expr| matches!(expr, Expr::Group(_)))
            .collect();

        // Operand-first (bd-168ef8): resolve every operand to a value.
        let mut operands = Vec::with_capacity(operand_exprs.len());
        for expr in operand_exprs {
            operands.push(self.eval(expr)?);
        }

        let sep = self.sep();
        // Coerce each operand to the operator's operand type (bd-dd7b5e).
        let coerced = operands
            .iter()
            .map(|value| value.coerce(op_cfg.operands, &sep))
            .collect::<Result<Vec<_>, _>>()?;

        self.realise(op, op_cfg, &coerced, &grouped, &sep)
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
        if op_cfg.command.is_some() {
            return Err(EvalError::Unsupported(format!(
                "command realisation for `{op}` (bd-3c1e6d) not yet wired"
            )));
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
            Mode::Llm => Err(EvalError::Unsupported(format!(
                "llm realisation for `{op}` (model+prompt) not yet wired"
            ))),
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

#[cfg(test)]
mod tests {
    use super::*;
    use crate::config;
    use serde_json::{Map, json};
    use std::path::Path;

    /// The SPEC canonical operator set (the subset exercised deterministically).
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
"##;
        config::parse_str(yaml, Path::new("test-config.yaml")).expect("valid test config")
    }

    /// Evaluate `expr` in det mode over an empty context and render the result.
    fn det(expr: &str) -> String {
        let cfg = config();
        let ctx = Context::empty(&cfg.context);
        evaluate(expr, &cfg, &ctx, Mode::Det)
            .unwrap_or_else(|e| panic!("eval `{expr}`: {e}"))
            .render(&ctx.sep())
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
        let out = evaluate("^-1", &cfg, &ctx, Mode::Det)
            .expect("message eval")
            .render(&ctx.sep());
        assert_eq!(out, "in rust");
        // Subject-of over the message (prefix template over a `^` index).
        let out = evaluate("#^-1", &cfg, &ctx, Mode::Det)
            .expect("subject eval")
            .render(&ctx.sep());
        assert_eq!(out, "subject of in rust");
    }

    #[test]
    fn context_read_resolves_and_missing_key_errors() {
        let cfg = config();
        let mut ctx = Context::empty(&cfg.context);
        ctx.merge([("k".to_owned(), json!("foo"))].into_iter().collect());
        assert_eq!(
            evaluate("$k", &cfg, &ctx, Mode::Det)
                .unwrap()
                .render(&ctx.sep()),
            "foo"
        );
        assert!(matches!(
            evaluate("$missing", &cfg, &ctx, Mode::Det),
            Err(EvalError::UnknownContextKey(_))
        ));
    }

    #[test]
    fn div_by_zero_is_a_loud_error() {
        let cfg = config();
        let ctx = Context::empty(&cfg.context);
        assert!(matches!(
            evaluate("1/0", &cfg, &ctx, Mode::Det),
            Err(EvalError::Realise(_))
        ));
    }

    #[test]
    fn unknown_operator_errors() {
        // `~` is not configured; the lexer won't even tokenise it, so this is a
        // lex error — the point is it fails loudly, not silently.
        let cfg = config();
        let ctx = Context::empty(&cfg.context);
        assert!(evaluate("a~b", &cfg, &ctx, Mode::Det).is_err());
    }

    #[test]
    fn llm_realisation_is_reported_unsupported_for_now() {
        let cfg = config();
        let ctx = Context::empty(&cfg.context);
        // `!` has only a det template here; in llm mode with no model it is
        // reported unsupported rather than silently wrong.
        let yaml = r##"
operators:
  ask: { op: "?", arity: 1, fixity: postfix, priority: 0, model: haiku, prompt: "q: %" }
"##;
        let llm_cfg = config::parse_str(yaml, Path::new("t.yaml")).unwrap();
        assert!(matches!(
            evaluate("x?", &llm_cfg, &ctx, Mode::Llm),
            Err(EvalError::Unsupported(_))
        ));
    }
}
