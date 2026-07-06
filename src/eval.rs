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
use crate::realise::RealiseError;
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

/// Parse `expr` and return its small-step reduction trace as rendered strings:
/// the initial expression, then each one-redex reduction, ending at the final
/// value (bd-9c366d, Harry's "step through an expansion to learn the language"
/// ask). Deterministic operators reduce instantly; each LLM operator step makes
/// one realisation call. Powers `nlir step` and the REPL Tab step-through.
///
/// # Errors
/// Returns [`EvalError`] on a lex/parse failure or any error while reducing.
pub fn step_trace(
    expr: &str,
    config: &Config,
    context: &mut Context,
    mode: Mode,
) -> Result<Vec<String>, EvalError> {
    let mut steps = Vec::new();
    step_trace_streaming(expr, config, context, mode, |rendered| {
        steps.push(rendered.to_owned());
    })?;
    Ok(steps)
}

/// Stream each small-step reduction as it is produced (bd-89eb89): the streaming
/// twin of [`step_trace`]. Instead of collecting every rendered step into a `Vec`
/// returned only at the end, it invokes `on_step` with each step's rendered string
/// the moment that step is taken — `on_step` fires first with the initial
/// (unreduced) statement, then once per reduction, in order. This is the
/// live-progress source for the CLI `nlir step` stream, the TUI workbench, and the
/// wasm `step()` view; [`step_trace`] is now a thin collector over it.
///
/// # Errors
/// Returns [`EvalError`] on a lex/parse failure or any error while reducing.
pub fn step_trace_streaming(
    expr: &str,
    config: &Config,
    context: &mut Context,
    mode: Mode,
    mut on_step: impl FnMut(&str),
) -> Result<(), EvalError> {
    let sigils = crate::config::operator_sigils(config);
    let tokens = lexer::tokenize(expr, &sigils).map_err(|error| {
        EvalError::Lex(format!("{error}\n{}", source_pointer(expr, error.position)))
    })?;
    let program = parser::parse_program(&tokens, &config.operators)
        .map_err(|error| EvalError::Parse(error.to_string()))?;
    let mut evaluator = Evaluator::new(config, context, mode);
    for statement in &program.statements {
        let mut current = statement.clone();
        on_step(&current.render_step());
        while let Step::Reduced(next) = evaluator.step_once(&current)? {
            current = next;
            on_step(&current.render_step());
        }
        // Push each statement's final value so later `;`-statements can read it
        // off the stack (mirrors `Evaluator::run`).
        if let Some(value) = as_value(&current) {
            evaluator.stack.push(value);
        }
    }
    Ok(())
}

/// Parse `expr` and produce the sequence of dataflow-graph FRAMES its small-step
/// reduction passes through (graph-viz epic bd-8ac9ad, slice G2): the animation
/// source G4 (kitty) and G5 (wasm) render via `graph_svg::render(&frame.graph)`.
/// Mirrors [`step_trace`] but captures a [`crate::graph::Graph`] per step instead
/// of a rendered string. Binding edges persist until their read is consumed
/// (stable [`crate::graph::NodeId`] layout keeps the graph from jumping), and each
/// frame records the node that just reduced (for highlight / caption).
///
/// # Errors
/// Returns [`EvalError`] on a lex/parse failure or any error while reducing.
pub fn step_frames(
    expr: &str,
    config: &Config,
    context: &mut Context,
    mode: Mode,
) -> Result<Vec<crate::graph::Frame>, EvalError> {
    let mut frames = Vec::new();
    step_frames_streaming(expr, config, context, mode, |frame| {
        frames.push(frame.clone());
    })?;
    Ok(frames)
}

/// Stream each dataflow-graph FRAME as it is produced (bd-89eb89): the streaming
/// twin of [`step_frames`], for the animate view. Instead of collecting every
/// [`crate::graph::Frame`] into a `Vec` returned only at the end, it invokes
/// `on_frame` with each frame the moment that reduction is taken — `on_frame`
/// fires first with frame 0 (the initial graph, `reduced: None`), then once per
/// reduction, in order. Frames are byte-for-byte identical to [`step_frames`]
/// (now a thin collector over this), so `animate()` consumes streamed and batched
/// frames the same way.
///
/// # Errors
/// Returns [`EvalError`] on a lex/parse failure or any error while reducing.
pub fn step_frames_streaming(
    expr: &str,
    config: &Config,
    context: &mut Context,
    mode: Mode,
    mut on_frame: impl FnMut(&crate::graph::Frame),
) -> Result<(), EvalError> {
    use crate::graph::{Frame, Graph, reduced_between};
    let sigils = crate::config::operator_sigils(config);
    let tokens = lexer::tokenize(expr, &sigils).map_err(|error| {
        EvalError::Lex(format!("{error}\n{}", source_pointer(expr, error.position)))
    })?;
    let program = parser::parse_program(&tokens, &config.operators)
        .map_err(|error| EvalError::Parse(error.to_string()))?;

    // The binding edges carry the ORIGINAL, stable endpoints across all frames;
    // Graph::frame re-applies them while each target read is still un-reduced.
    let original_bindings = Graph::from_program(&program).binding_edges();

    let mut evaluator = Evaluator::new(config, context, mode);
    let mut statements = program.statements.clone();
    on_frame(&Frame {
        graph: Graph::frame(&statements, &original_bindings),
        reduced: None,
    });
    for i in 0..statements.len() {
        while let Step::Reduced(next) = evaluator.step_once(&statements[i])? {
            let before = Graph::frame(&statements, &original_bindings);
            statements[i] = next;
            let graph = Graph::frame(&statements, &original_bindings);
            let reduced = reduced_between(&before, &graph);
            on_frame(&Frame { graph, reduced });
        }
        // Push the finished statement's value so later `;`-statements resolve.
        if let Some(value) = as_value(&statements[i]) {
            evaluator.stack.push(value);
        }
    }
    Ok(())
}

/// Async mirror of [`step_frames`] (graph-viz G2 through the realiser seam,
/// bd-bec201): the step-frame animation source driven through the injected
/// [`crate::realiser::Realiser`], for LLM-mode graph animation — watch an
/// operator realise as the dataflow graph evolves — in the browser (G5) or
/// `--save-animation` (G4). Deterministic frames never await; each effectful
/// redex is one realiser call. Same [`crate::graph::Frame`] output as
/// [`step_frames`].
///
/// # Errors
/// Returns [`EvalError`] on a lex/parse failure or any error while reducing.
pub async fn step_frames_async<R: crate::realiser::Realiser>(
    expr: &str,
    config: &Config,
    context: &mut Context,
    mode: Mode,
    realiser: &R,
) -> Result<Vec<crate::graph::Frame>, EvalError> {
    let mut frames = Vec::new();
    step_frames_streaming_async(expr, config, context, mode, realiser, |frame| {
        frames.push(frame.clone());
    })
    .await?;
    Ok(frames)
}

/// Async streaming twin of [`step_frames_streaming`] (bd-89eb89): the live
/// graph-animation source for llm mode (G5 browser / G4 `--save-animation`),
/// firing `on_frame` the moment each step's realisation completes inside the
/// per-step await loop. [`step_frames_async`] is now a thin collector over it.
///
/// # Errors
/// Returns [`EvalError`] on a lex/parse failure or any error while reducing.
pub async fn step_frames_streaming_async<R: crate::realiser::Realiser>(
    expr: &str,
    config: &Config,
    context: &mut Context,
    mode: Mode,
    realiser: &R,
    mut on_frame: impl FnMut(&crate::graph::Frame),
) -> Result<(), EvalError> {
    use crate::graph::{Frame, Graph, reduced_between};
    let sigils = crate::config::operator_sigils(config);
    let tokens = lexer::tokenize(expr, &sigils).map_err(|error| {
        EvalError::Lex(format!("{error}\n{}", source_pointer(expr, error.position)))
    })?;
    let program = parser::parse_program(&tokens, &config.operators)
        .map_err(|error| EvalError::Parse(error.to_string()))?;

    let original_bindings = Graph::from_program(&program).binding_edges();

    let mut evaluator = Evaluator::new(config, context, mode);
    let mut statements = program.statements.clone();
    on_frame(&Frame {
        graph: Graph::frame(&statements, &original_bindings),
        reduced: None,
    });
    for i in 0..statements.len() {
        while let Step::Reduced(next) = evaluator.step_once_async(&statements[i], realiser).await? {
            let before = Graph::frame(&statements, &original_bindings);
            statements[i] = next;
            let graph = Graph::frame(&statements, &original_bindings);
            let reduced = reduced_between(&before, &graph);
            on_frame(&Frame { graph, reduced });
        }
        if let Some(value) = as_value(&statements[i]) {
            evaluator.stack.push(value);
        }
    }
    Ok(())
}

/// The operand-first evaluator: a config + context + a run-scoped stack. The
/// context is mutable so `key=RHS` assignment can write through (SPEC: context
/// writes happen immediately).
pub struct Evaluator<'a> {
    config: &'a Config,
    context: &'a mut Context,
    mode: Mode,
    stack: Stack,
    /// Bounded DAG concurrency for independent operand subtrees (config
    /// `defaults.parallelism`, default 8) — SPEC §Execution graph (bd-780dbf).
    parallelism: usize,
    /// Per-run memoisation of operator realisations keyed by
    /// `(op, mode, model, grouping, operand-texts)` — SPEC §parallelism dedupes
    /// identical subcalls when `_cache` is on (bd-1d078c). Behind a `Mutex` so
    /// concurrently-evaluated operand subtrees share one cache (bd-780dbf).
    realise_cache: std::sync::Mutex<std::collections::HashMap<String, Value>>,
    /// Positional argument frames for form application (`%`, bd-5dd86f). Applying
    /// a form pushes its evaluated args as a frame; inside the body a
    /// non-negative `$N` resolves to `args[N]`, shadowing the run stack
    /// (argument-frame hygiene). Popped when the application returns.
    arg_frames: Vec<Vec<Value>>,
}

/// The outcome of a single small-step reduction ([`Evaluator::step_once`],
/// bd-9c366d).
#[derive(Debug, Clone, PartialEq)]
pub enum Step {
    /// One redex was reduced; the tree rewritten with that node replaced (a
    /// reduced sub-expression is spliced back as [`Expr::Value`]). Call
    /// `step_once` again to keep reducing.
    Reduced(Expr),
    /// `expr` was already a fully-reduced value; nothing left to reduce.
    Done(Value),
}

/// The already-reduced [`Value`] of an expression node, if it is one. Literals
/// count as values (so a literal never wastes a visible reduction step), as does
/// a `Group`/`Serial`/`List` all of whose children are values. Reads (`$`, `^`),
/// interpolating quotes, assignments, and operator applications are NOT yet
/// values — they each take a step.
fn as_value(expr: &Expr) -> Option<Value> {
    match expr {
        Expr::Value(v) => Some(v.clone()),
        Expr::Bare(s) => Some(Value::string(s.clone())),
        Expr::Number(n) => Some(Value::number(*n)),
        Expr::Quoted {
            content,
            interpolate: false,
        } => Some(Value::string(content.clone())),
        Expr::Group(inner) | Expr::Serial(inner) => as_value(inner),
        // A quoted form `{…}` is a value: its inner is NOT evaluated. Yields a
        // Value::Form carrying the inner AST (code-as-data, bd-5dd86f).
        Expr::Quote(inner) => Some(Value::form((**inner).clone())),
        Expr::List(items) => items
            .iter()
            .map(as_value)
            .collect::<Option<Vec<_>>>()
            .map(Value::list),
        _ => None,
    }
}

impl<'a> Evaluator<'a> {
    /// Build an evaluator over `config` + `context` in `mode`, with a fresh
    /// empty stack.
    #[must_use]
    pub fn new(config: &'a Config, context: &'a mut Context, mode: Mode) -> Self {
        // $_stdin-on-stack (bd-9a3e7c, Harry's "$_stdin first on the stack when
        // piped"): seed the premise stack at position 0 with the reserved
        // `_stdin` transient, so an operator with a missing operand can pull the
        // piped input from the stack (`… | nlir -e '&'`). Only present when stdin
        // was piped (the CLI sets it); every other path starts with an empty stack.
        let mut stack = Stack::new();
        if let Some(json) = context.get("_stdin") {
            stack.push(json_to_value_forms(json, config));
        }
        Self {
            parallelism: config.defaults.parallelism.max(1),
            config,
            context,
            mode,
            stack,
            realise_cache: std::sync::Mutex::new(std::collections::HashMap::new()),
            arg_frames: Vec::new(),
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

    /// Reduce the leftmost-innermost redex of `expr` by exactly one step
    /// (bd-9c366d, "learn the language" step-through). Returns [`Step::Reduced`]
    /// with the rewritten tree — one node replaced by its [`Value`], spliced
    /// back as [`Expr::Value`] so the surrounding expression can keep reducing —
    /// or [`Step::Done`] when `expr` is already a value. Deterministic operators
    /// reduce instantly; each LLM operator application is a single step (one
    /// realisation). Powers `nlir step` + the REPL Tab step-through.
    ///
    /// # Errors
    /// Propagates any [`EvalError`] from evaluating the reduced node.
    pub fn step_once(&mut self, expr: &Expr) -> Result<Step, EvalError> {
        if let Some(value) = as_value(expr) {
            return Ok(Step::Done(value));
        }
        Ok(Step::Reduced(self.reduce(expr)?))
    }

    /// One reduction of a non-value node: recurse into the leftmost non-value
    /// child and step it; once every child is a value, evaluate this node and
    /// replace it with the resulting [`Expr::Value`].
    fn reduce(&mut self, expr: &Expr) -> Result<Expr, EvalError> {
        match expr {
            // A read / interpolating quote resolves to its value in one step.
            Expr::ContextRead(_)
            | Expr::StackPeek
            | Expr::StackIndex(_)
            | Expr::Message { .. }
            | Expr::MessageRange { .. }
            | Expr::Quoted {
                interpolate: true, ..
            } => Ok(Expr::Value(self.eval(expr)?)),
            // Grouping/serial: step the inner subtree, preserving the wrapper
            // until its inner becomes a value (then `as_value` absorbs it).
            Expr::Group(inner) => Ok(Expr::Group(Box::new(self.reduce(inner)?))),
            Expr::Serial(inner) => Ok(Expr::Serial(Box::new(self.reduce(inner)?))),
            // List: reduce the leftmost non-value item.
            Expr::List(items) => {
                let mut items = items.clone();
                if let Some(i) = items.iter().position(|it| as_value(it).is_none()) {
                    items[i] = self.reduce(&items[i])?;
                }
                Ok(Expr::List(items))
            }
            // Assignment: reduce the RHS; once it is a value, perform the write.
            Expr::Assign { key, value } => {
                if as_value(value).is_some() {
                    Ok(Expr::Value(self.eval(expr)?))
                } else {
                    Ok(Expr::Assign {
                        key: key.clone(),
                        value: Box::new(self.reduce(value)?),
                    })
                }
            }
            // Application: reduce the leftmost non-value operand; once all
            // operands are values, apply the operator (one realisation).
            Expr::Apply {
                op,
                fixity,
                operands,
            } => {
                if let Some(i) = operands.iter().position(|o| as_value(o).is_none()) {
                    let mut operands = operands.clone();
                    operands[i] = self.reduce(&operands[i])?;
                    Ok(Expr::Apply {
                        op: op.clone(),
                        fixity: *fixity,
                        operands,
                    })
                } else {
                    Ok(Expr::Value(self.eval(expr)?))
                }
            }
            // Literals / already-reduced values are caught by `as_value` before
            // `reduce` is reached; evaluate defensively for exhaustiveness.
            // Form application reduces in one visible step (bd-5dd86f).
            Expr::Value(_)
            | Expr::Bare(_)
            | Expr::Number(_)
            | Expr::Quoted { .. }
            | Expr::Quote(_)
            | Expr::FormApply { .. } => Ok(Expr::Value(self.eval(expr)?)),
        }
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
            // A quoted form `{…}` does NOT evaluate its inner; it yields the form
            // as data (Value::Form). Application (`%`) evaluates it with $N bound
            // to the arguments (bd-5dd86f).
            Expr::Quote(inner) => Ok(Value::form((**inner).clone())),
            Expr::ContextRead(name) => self.read_context(name),
            Expr::StackPeek => self
                .stack
                .peek()
                .cloned()
                .ok_or_else(|| EvalError::Stack("`$` peek of an empty stack".to_owned())),
            Expr::StackIndex(index) => self.read_positional(*index),
            Expr::Message { role, index } => self.eval_message(*role, index),
            Expr::MessageRange { role, start, end } => self.eval_message_range(*role, start, end),
            // Grouping overrides precedence; its value is the inner value (parens
            // are preserved at the string-realisation boundary, not in the value).
            Expr::Group(inner) => self.eval(inner),
            Expr::FormApply { form, args } => self.eval_form_apply(form, args),
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
            // A value spliced in by step-through evaluation is already reduced.
            Expr::Value(value) => Ok(value.clone()),
        }
    }

    /// Read `$name` from the context, converting the stored JSON to a typed
    /// value. A missing key is a loud error.
    fn read_context(&self, name: &str) -> Result<Value, EvalError> {
        self.context
            .get(name)
            .map(|json| json_to_value_forms(json, self.config))
            .ok_or_else(|| EvalError::UnknownContextKey(name.to_owned()))
    }

    /// Evaluate a `^` message index: resolve the index expression to a number,
    /// then read the role-filtered view's message content.
    fn eval_message(&mut self, role: MessageRole, index: &Expr) -> Result<Value, EvalError> {
        let sep = self.sep();
        let i = self.eval_index(index, &sep)?;
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

    /// Evaluate a `M^N` message range: resolve `start`/`end` to indices, then
    /// join the messages of `role` in that (inclusive, clamped) range with
    /// `_sep` (SPEC §Messages, bd-c3fc30; calls [`MessageIndex::range`]).
    fn eval_message_range(
        &mut self,
        role: MessageRole,
        start: &Expr,
        end: &Expr,
    ) -> Result<Value, EvalError> {
        let sep = self.sep();
        let start_i = self.eval_index(start, &sep)?;
        let end_i = self.eval_index(end, &sep)?;
        let view = MessageIndex::new(
            self.context.messages(),
            &self.config.context.messages.views,
            &self.config.context.messages.role_field,
            &self.config.context.messages.content_field,
        );
        Ok(Value::string(view.range(role, start_i, end_i, &sep)))
    }

    /// Evaluate an expression to a truncated `i64` message index (coerces to
    /// number first). Shared by the prefix `^N` read and the `M^N` range.
    fn eval_index(&mut self, index: &Expr, sep: &str) -> Result<i64, EvalError> {
        let number = self
            .eval(index)?
            .coerce(TypeName::Number, sep)?
            .as_number()
            .ok_or_else(|| EvalError::Unsupported("message index is not a number".to_owned()))?;
        #[allow(clippy::cast_possible_truncation)]
        Ok(number.trunc() as i64)
    }

    /// Evaluate an operator application: operand-first eval, operand coercion,
    /// then realisation resolution + dispatch.
    /// Resolve a positional `$N` read (bd-5dd86f argument-frame hygiene): inside
    /// a form application, a non-negative `$N` binds to the current argument
    /// frame's arg `N`, shadowing the run stack; otherwise — a negative index, no
    /// active frame, or an out-of-range frame index — it peeks the run stack.
    fn read_positional(&self, index: i64) -> Result<Value, EvalError> {
        if index >= 0 {
            if let Some(value) = self
                .arg_frames
                .last()
                .and_then(|frame| frame.get(index as usize))
            {
                return Ok(value.clone());
            }
        }
        self.stack
            .peek_index(index)
            .cloned()
            .ok_or_else(|| EvalError::Stack(format!("`${index}` is out of range")))
    }

    /// Apply a form to arguments (`form % args`, bd-5dd86f): evaluate `form` to a
    /// [`Value::Form`], evaluate each argument, push a positional argument frame
    /// (`$0/$1/…`), evaluate the form's body under it, then pop. A non-form
    /// callee is an error — the left of `%` must be a `{…}` form.
    fn eval_form_apply(&mut self, form: &Expr, args: &[Expr]) -> Result<Value, EvalError> {
        // Higher-order builtin forms `$map`/`$fold` (bd-14af74): `$map%(f,list)`
        // applies form `f` to each list item (`$0` = the item) collecting a list;
        // `$fold%(f,list)` reduces left-to-right (`$0` = acc, `$1` = item). They are
        // reserved names detected ONLY in application position, and only when the
        // context does not define the name — a user-defined `map`/`fold` form still
        // wins (normal form apply below).
        if let Expr::ContextRead(name) = form {
            if matches!(name.as_str(), "map" | "fold" | "scan" | "filter")
                && self.context.get(name).is_none()
            {
                return self.eval_higher_order(name, args);
            }
            if matches!(name.as_str(), "if" | "nth" | "sort" | "contains")
                && self.context.get(name).is_none()
            {
                return self.eval_value_builtin(name, args);
            }
        }
        let body = match self.eval(form)? {
            Value::Form(inner) => *inner,
            _ => {
                return Err(EvalError::Unsupported(
                    "cannot apply a non-form value; the left of `%` must be a {…} form".to_owned(),
                ));
            }
        };
        let mut frame = Vec::with_capacity(args.len());
        for arg in args {
            frame.push(self.eval(arg)?);
        }
        self.arg_frames.push(frame);
        let result = self.eval(&body);
        self.arg_frames.pop();
        result
    }

    /// Apply a higher-order builtin (`map`/`fold`, bd-14af74) over a list. Shared
    /// operand shape `args = [form, list]`; `map` applies `form` to each item
    /// (`$0` = item) collecting a [`Value::List`]; `fold` reduces left-to-right
    /// (`$0` = acc, `$1` = item), seeded by the first element.
    fn eval_higher_order(&mut self, name: &str, args: &[Expr]) -> Result<Value, EvalError> {
        let (body, items) = self.higher_order_operands(name, args)?;
        self.run_higher_order(name, &body, items)
    }

    /// Value-level builtins dispatched at `%`-application (like `$map`/`$fold`)
    /// that operate on evaluated VALUES, not a form-per-item (basics batch,
    /// docs/design/basics-primitives.md §3–4):
    /// - `$if%(cond, then, else)` → `then` if `cond` is truthy else `else`; the
    ///   untaken branch is NOT evaluated (short-circuit).
    /// - `$nth%(i, list)` → the i-th element (0-based; negative = from the end).
    /// - `$sort%list` → the list ascending (numeric if all-numeric, else lexical).
    /// - `$contains%(haystack, needle)` → a `Value::Bool`: does the rendered
    ///   haystack contain the (trimmed) rendered needle? A containment predicate
    ///   for `$filter`/`$if` conditions and the `~>` det stub.
    fn eval_value_builtin(&mut self, name: &str, args: &[Expr]) -> Result<Value, EvalError> {
        match name {
            "if" => {
                if args.len() != 3 {
                    return Err(builtin_arity_err(name, "(cond, then, else)", args.len()));
                }
                if value_is_truthy(&self.eval(&args[0])?) {
                    self.eval(&args[1])
                } else {
                    self.eval(&args[2])
                }
            }
            "nth" => {
                if args.len() != 2 {
                    return Err(builtin_arity_err(name, "(index, list)", args.len()));
                }
                let index = self.eval(&args[0])?;
                let items = as_items(self.eval(&args[1])?);
                let sep = self.sep();
                let at = resolve_nth(&index, items.len(), &sep)?;
                Ok(items[at].clone())
            }
            "sort" => {
                let items = self.value_builtin_list(args)?;
                let sep = self.sep();
                Ok(Value::list(sort_values(items, &sep)))
            }
            "contains" => {
                if args.len() != 2 {
                    return Err(builtin_arity_err(name, "(haystack, needle)", args.len()));
                }
                let hay = self.eval(&args[0])?;
                let needle = self.eval(&args[1])?;
                let sep = self.sep();
                Ok(Value::bool(
                    hay.render(&sep).contains(needle.render(&sep).trim()),
                ))
            }
            _ => unreachable!("unknown value builtin: {name}"),
        }
    }

    /// The list operand(s) for a value builtin: a single arg spreads a
    /// [`Value::List`], otherwise each arg is one item.
    fn value_builtin_list(&mut self, args: &[Expr]) -> Result<Vec<Value>, EvalError> {
        if args.len() == 1 {
            return Ok(as_items(self.eval(&args[0])?));
        }
        let mut items = Vec::with_capacity(args.len());
        for arg in args {
            items.push(self.eval(arg)?);
        }
        Ok(items)
    }

    /// Async twin of [`eval_value_builtin`](Self::eval_value_builtin): the operand
    /// evaluations may `await` the realiser (llm mode). `$if` still short-circuits
    /// — only the taken branch is evaluated.
    async fn eval_value_builtin_async<R: crate::realiser::Realiser>(
        &mut self,
        name: &str,
        args: &[Expr],
        realiser: &R,
    ) -> Result<Value, EvalError> {
        match name {
            "if" => {
                if args.len() != 3 {
                    return Err(builtin_arity_err(name, "(cond, then, else)", args.len()));
                }
                let cond = self.eval_async(&args[0], realiser).await?;
                if value_is_truthy(&cond) {
                    self.eval_async(&args[1], realiser).await
                } else {
                    self.eval_async(&args[2], realiser).await
                }
            }
            "nth" => {
                if args.len() != 2 {
                    return Err(builtin_arity_err(name, "(index, list)", args.len()));
                }
                let index = self.eval_async(&args[0], realiser).await?;
                let items = as_items(self.eval_async(&args[1], realiser).await?);
                let sep = self.sep();
                let at = resolve_nth(&index, items.len(), &sep)?;
                Ok(items[at].clone())
            }
            "sort" => {
                let items = if args.len() == 1 {
                    as_items(self.eval_async(&args[0], realiser).await?)
                } else {
                    let mut items = Vec::with_capacity(args.len());
                    for arg in args {
                        items.push(self.eval_async(arg, realiser).await?);
                    }
                    items
                };
                let sep = self.sep();
                Ok(Value::list(sort_values(items, &sep)))
            }
            "contains" => {
                if args.len() != 2 {
                    return Err(builtin_arity_err(name, "(haystack, needle)", args.len()));
                }
                let hay = self.eval_async(&args[0], realiser).await?;
                let needle = self.eval_async(&args[1], realiser).await?;
                let sep = self.sep();
                Ok(Value::bool(
                    hay.render(&sep).contains(needle.render(&sep).trim()),
                ))
            }
            _ => unreachable!("unknown value builtin: {name}"),
        }
    }

    /// The value-level map/fold core (bd-14af74): `map` applies `body` per item
    /// (`$0` = item) collecting a list; `fold` reduces left-to-right (`$0` = acc,
    /// `$1` = item), seeded by the first element. Shared by the `$map`/`$fold`
    /// named builtins and a `builtin:`-realised glyph operator (bd-44c294).
    fn run_higher_order(
        &mut self,
        name: &str,
        body: &Expr,
        items: Vec<Value>,
    ) -> Result<Value, EvalError> {
        if name == "map" {
            let mut out = Vec::with_capacity(items.len());
            for item in items {
                self.arg_frames.push(vec![item]);
                let mapped = self.eval(body);
                self.arg_frames.pop();
                out.push(mapped?);
            }
            return Ok(Value::list(out));
        }
        if name == "scan" {
            // running fold (J's `\`): [acc0, acc1, …] where acc0 = items[0] and
            // acc_i = body(acc_{i-1}, items[i]) — prefix sums, running consensus.
            let mut iter = items.into_iter();
            let Some(first) = iter.next() else {
                return Ok(Value::list(Vec::new()));
            };
            let mut acc = first.clone();
            let mut out = vec![first];
            for item in iter {
                self.arg_frames.push(vec![acc.clone(), item]);
                let next = self.eval(body);
                self.arg_frames.pop();
                acc = next?;
                out.push(acc.clone());
            }
            return Ok(Value::list(out));
        }
        if name == "filter" {
            // keep items whose predicate body ($0 = item) is truthy (APL compress).
            let mut out = Vec::new();
            for item in items {
                self.arg_frames.push(vec![item.clone()]);
                let verdict = self.eval(body);
                self.arg_frames.pop();
                if value_is_truthy(&verdict?) {
                    out.push(item);
                }
            }
            return Ok(Value::list(out));
        }
        // fold
        let mut iter = items.into_iter();
        let mut acc = iter
            .next()
            .ok_or_else(|| EvalError::Unsupported(format!("`{name}` needs a non-empty list")))?;
        for item in iter {
            self.arg_frames.push(vec![acc, item]);
            let folded = self.eval(body);
            self.arg_frames.pop();
            acc = folded?;
        }
        Ok(acc)
    }

    /// Realise a `form:`-backed operator (bd-44c294): apply the operator's form to
    /// its already-evaluated operands, binding them to `$0`, `$1`, … — i.e.
    /// `{form}%(operands)`. The form source is parsed with the config grammar.
    fn apply_form_op(&mut self, form_src: &str, operands: &[Value]) -> Result<Value, EvalError> {
        let body = self.parse_op_form(form_src)?;
        self.arg_frames.push(operands.to_vec());
        let result = self.eval(&body);
        self.arg_frames.pop();
        result
    }

    /// Realise a `builtin:`-backed operator (bd-44c294): dispatch `map`/`fold`
    /// over the already-evaluated `(form, list)` operands.
    fn apply_builtin_op(&mut self, name: &str, operands: &[Value]) -> Result<Value, EvalError> {
        let (body, items) = builtin_op_operands(name, operands)?;
        self.run_higher_order(name, &body, items)
    }

    /// Parse a `form:` operator's source into its body expression, unwrapping the
    /// outer `{…}` quote if present (bd-44c294).
    fn parse_op_form(&self, form_src: &str) -> Result<Expr, EvalError> {
        let expr = parse_stored_form(form_src, self.config).ok_or_else(|| {
            EvalError::Unsupported(format!("operator `form:` did not parse: `{form_src}`"))
        })?;
        Ok(match expr {
            Expr::Quote(inner) => *inner,
            other => other,
        })
    }

    /// Async twin of [`run_higher_order`](Self::run_higher_order) (bd-44c294): the
    /// map/fold core through the async realiser, so a `builtin:` glyph operator
    /// (or `$map`/`$fold`) may realise llm ops per item. Owned `name`/`body` so
    /// they move into the boxed future.
    fn run_higher_order_async<'e, R: crate::realiser::Realiser>(
        &'e mut self,
        name: String,
        body: Expr,
        items: Vec<Value>,
        realiser: &'e R,
    ) -> std::pin::Pin<Box<dyn std::future::Future<Output = Result<Value, EvalError>> + 'e>> {
        Box::pin(async move {
            if name == "map" {
                let mut out = Vec::with_capacity(items.len());
                for item in items {
                    self.arg_frames.push(vec![item]);
                    let mapped = self.eval_async(&body, realiser).await;
                    self.arg_frames.pop();
                    out.push(mapped?);
                }
                return Ok(Value::list(out));
            }
            if name == "scan" {
                let mut iter = items.into_iter();
                let Some(first) = iter.next() else {
                    return Ok(Value::list(Vec::new()));
                };
                let mut acc = first.clone();
                let mut out = vec![first];
                for item in iter {
                    self.arg_frames.push(vec![acc.clone(), item]);
                    let next = self.eval_async(&body, realiser).await;
                    self.arg_frames.pop();
                    acc = next?;
                    out.push(acc.clone());
                }
                return Ok(Value::list(out));
            }
            if name == "filter" {
                let mut out = Vec::new();
                for item in items {
                    self.arg_frames.push(vec![item.clone()]);
                    let verdict = self.eval_async(&body, realiser).await;
                    self.arg_frames.pop();
                    if value_is_truthy(&verdict?) {
                        out.push(item);
                    }
                }
                return Ok(Value::list(out));
            }
            let mut iter = items.into_iter();
            let mut acc = iter.next().ok_or_else(|| {
                EvalError::Unsupported(format!("`{name}` needs a non-empty list"))
            })?;
            for item in iter {
                self.arg_frames.push(vec![acc, item]);
                let folded = self.eval_async(&body, realiser).await;
                self.arg_frames.pop();
                acc = folded?;
            }
            Ok(acc)
        })
    }

    /// Resolve the shared `(form, list)` operands for a `map`/`fold` builtin: the
    /// first arg must be a `{…}` form; the second is coerced to a list (a lone
    /// non-list value becomes a one-element list).
    fn higher_order_operands(
        &mut self,
        name: &str,
        args: &[Expr],
    ) -> Result<(Expr, Vec<Value>), EvalError> {
        if args.len() != 2 {
            return Err(EvalError::Unsupported(format!(
                "`${name}` takes (form, list); got {} argument(s)",
                args.len()
            )));
        }
        let body = match self.eval(&args[0])? {
            Value::Form(inner) => *inner,
            _ => {
                return Err(EvalError::Unsupported(format!(
                    "`${name}`'s first argument must be a {{…}} form"
                )));
            }
        };
        let items = match self.eval(&args[1])? {
            Value::List(items) => items,
            other => vec![other],
        };
        Ok((body, items))
    }

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

            // Operand-first (bd-168ef8). Independent side-effect-free operand
            // subtrees evaluate concurrently, bounded by `parallelism` (SPEC
            // §Execution graph; bd-780dbf). A subtree that writes context (`=`)
            // or touches the stack is not parallel-safe → sequential (bd-0d9f66);
            // a backtick-serial operand parallelises with its siblings but runs
            // serially inside (bd-f66c32).
            let operands = if operand_exprs.len() > 1
                && self.parallelism > 1
                && operand_exprs
                    .iter()
                    .all(|e| is_parallel_safe(e, self.config))
            {
                let cache_on = self.context.cache();
                eval_operands_parallel(
                    operand_exprs,
                    self.config,
                    self.context,
                    self.mode,
                    cache_on,
                    &self.realise_cache,
                    self.parallelism,
                )?
            } else {
                let mut operands = Vec::with_capacity(operand_exprs.len());
                for expr in operand_exprs {
                    operands.push(self.eval(expr)?);
                }
                operands
            };

            // A list operand spreads into a variadic op — `&[a,b,c]` ≡ `a&b&c`
            // (SPEC §Structure; bd-02a795). Non-variadic ops keep the list as one
            // value (it renders via `_sep`).
            if op_cfg.arity == Arity::Variadic {
                spread_lists(operands, grouped)
            } else {
                (operands, grouped)
            }
        };

        // do-N-times (`{form}_N`, bd-5dd86f): the repeat operator `_` lifts from
        // text to forms — a Form first operand COMPOSES the form N times instead
        // of coercing it to source text. `{$0+1}_3 % 5` -> 8. Intercept before
        // operand coercion (which would otherwise flatten the form to source).
        if op == "_" && matches!(operands.first(), Some(Value::Form(_))) {
            return self.compose_form(&operands);
        }

        // Glyph operators (bd-44c294): a `builtin:`/`form:`-realised operator
        // dispatches BEFORE operand coercion — the operands go RAW to the builtin
        // (map/fold over a `(form, list)`) or the form (bound to `$0`, `$1`, …).
        if let Some(builtin) = op_cfg.builtin.as_deref() {
            return self.apply_builtin_op(builtin, &operands);
        }
        if let Some(form_src) = op_cfg.form.as_deref() {
            return self.apply_form_op(form_src, &operands);
        }
        // A `det:` form is a det-mode-only realisation (bd-6f9c1d): applied like
        // `form:` but ONLY in Mode::Det, so an llm op (`~>`) gets a computed det
        // stub (a real Bool) while its model still realises in llm mode.
        if self.mode == Mode::Det {
            if let Some(det_src) = op_cfg.det.as_deref() {
                return self.apply_form_op(det_src, &operands);
            }
        }

        let sep = self.sep();
        // Coerce each operand to the operator's operand type (bd-dd7b5e).
        let coerced = operands
            .iter()
            .map(|value| coerce_operand(value, op_cfg.operands, &sep, self.mode, self.config))
            .collect::<Result<Vec<_>, _>>()?;

        let cache_on = self.context.cache();
        realise_cached(
            op,
            op_cfg,
            &coerced,
            &grouped,
            &sep,
            self.mode,
            self.config,
            cache_on,
            &self.realise_cache,
        )
    }

    /// do-N-times: `{form}_N` composes `form` N times into a new form (bd-5dd86f).
    /// `operands` = `[Value::Form, count]`; the result is a form whose body is
    /// `form % (form % (… % $0))` (N nested applications), so applying it runs
    /// the form N times. N=0 is the identity form `{$0}`. This is the `_` repeat
    /// operator lifted from text-repeat to form-compose.
    fn compose_form(&self, operands: &[Value]) -> Result<Value, EvalError> {
        let sep = self.sep();
        let (inner, count) = match operands {
            [Value::Form(inner), count] => (inner, count),
            _ => {
                return Err(EvalError::Unsupported(
                    "`{form}_N` needs a form and a numeric repeat count".to_owned(),
                ));
            }
        };
        let n = count
            .coerce_deterministic(TypeName::Number, &sep)
            .and_then(|value| value.as_number())
            .filter(|n| n.is_finite() && *n >= 0.0)
            .ok_or_else(|| {
                EvalError::Unsupported(
                    "`{form}_N` repeat count must be a non-negative number".to_owned(),
                )
            })?;
        #[allow(clippy::cast_possible_truncation, clippy::cast_sign_loss)]
        let n = n.trunc() as usize;
        // Nest N applications of the form around the composed form's own `$0`.
        // Build the inner form node as `Expr::Quote` (renders `{…}`) rather than
        // an `Expr::Value` splice (renders `«…»`), so the COMPOSED form still
        // round-trips through context persistence — named do-N `g=({f}_N);$g%x`.
        let mut body = Expr::StackIndex(0);
        for _ in 0..n {
            body = Expr::FormApply {
                form: Box::new(Expr::Quote(inner.clone())),
                args: vec![body],
            };
        }
        Ok(Value::form(body))
    }

    /// Async mirror of [`eval`](Self::eval) (bd-bec201, nlir-wasm P0): the same
    /// operand-first evaluation, but the two EFFECTFUL sites (operator
    /// realisation + llm-mode operand coercion) `await` the injected
    /// [`Realiser`] instead of calling the native backend directly. Pure nodes
    /// (reads, literals, message views) delegate to the sync [`eval`](Self::eval)
    /// — they can contain no effectful call. Operands evaluate SERIALLY (no
    /// `thread::scope`; wasm has no threads — the seam is at realisation, not
    /// scheduling). This is the entry the browser drives via `wasm-bindgen-futures`.
    ///
    /// # Errors
    /// Propagates any [`EvalError`], including realiser failures.
    fn eval_async<'e, R: crate::realiser::Realiser>(
        &'e mut self,
        expr: &'e Expr,
        realiser: &'e R,
    ) -> std::pin::Pin<Box<dyn std::future::Future<Output = Result<Value, EvalError>> + 'e>> {
        Box::pin(async move {
            match expr {
                // Pure leaves: no effectful realisation reachable — reuse sync eval.
                Expr::Bare(_)
                | Expr::Quoted { .. }
                | Expr::Number(_)
                | Expr::ContextRead(_)
                | Expr::StackPeek
                | Expr::StackIndex(_)
                | Expr::Message { .. }
                | Expr::MessageRange { .. }
                | Expr::Value(_)
                | Expr::Quote(_) => self.eval(expr),
                Expr::Group(inner) | Expr::Serial(inner) => self.eval_async(inner, realiser).await,
                Expr::List(items) => {
                    let mut values = Vec::with_capacity(items.len());
                    for item in items {
                        values.push(self.eval_async(item, realiser).await?);
                    }
                    Ok(Value::list(values))
                }
                Expr::Assign { key, value } => {
                    let assigned = self.eval_async(value, realiser).await?;
                    self.context
                        .set(key.clone(), value_to_json(&assigned))
                        .map_err(|error| EvalError::ContextWrite(error.to_string()))?;
                    Ok(assigned)
                }
                Expr::Apply { op, operands, .. } => {
                    self.eval_apply_async(op, operands, realiser).await
                }
                Expr::FormApply { form, args } => {
                    // Higher-order builtins `$map`/`$fold` (bd-14af74), async twin:
                    // same reserved-name detection as `eval_higher_order`, driven
                    // through the async realiser so the mapping form may be llm.
                    if let Expr::ContextRead(name) = form.as_ref() {
                        if matches!(name.as_str(), "map" | "fold" | "scan" | "filter")
                            && self.context.get(name).is_none()
                        {
                            if args.len() != 2 {
                                return Err(EvalError::Unsupported(format!(
                                    "`${name}` takes (form, list); got {} argument(s)",
                                    args.len()
                                )));
                            }
                            let hbody = match self.eval_async(&args[0], realiser).await? {
                                Value::Form(inner) => *inner,
                                _ => {
                                    return Err(EvalError::Unsupported(format!(
                                        "`${name}`'s first argument must be a {{…}} form"
                                    )));
                                }
                            };
                            let items = match self.eval_async(&args[1], realiser).await? {
                                Value::List(items) => items,
                                other => vec![other],
                            };
                            return self
                                .run_higher_order_async(name.clone(), hbody, items, realiser)
                                .await;
                        }
                        if matches!(name.as_str(), "if" | "nth" | "sort" | "contains")
                            && self.context.get(name).is_none()
                        {
                            return self.eval_value_builtin_async(name, args, realiser).await;
                        }
                    }
                    // Form application (bd-5dd86f), async: eval the form + args
                    // (may await), push the argument frame, eval the body, pop.
                    let body = match self.eval_async(form, realiser).await? {
                        Value::Form(inner) => *inner,
                        _ => {
                            return Err(EvalError::Unsupported(
                                "cannot apply a non-form value; the left of `%` must be a {…} form"
                                    .to_owned(),
                            ));
                        }
                    };
                    let mut frame = Vec::with_capacity(args.len());
                    for arg in args {
                        frame.push(self.eval_async(arg, realiser).await?);
                    }
                    self.arg_frames.push(frame);
                    let result = self.eval_async(&body, realiser).await;
                    self.arg_frames.pop();
                    result
                }
            }
        })
    }

    /// Async mirror of [`eval_apply`](Self::eval_apply): operand-first (serial)
    /// eval, then `await` the async coercion + realisation. The per-run realise
    /// cache is intentionally NOT consulted here (the async entry recomputes;
    /// caching the async path is a follow-up).
    fn eval_apply_async<'e, R: crate::realiser::Realiser>(
        &'e mut self,
        op: &'e str,
        operand_exprs: &'e [Expr],
        realiser: &'e R,
    ) -> std::pin::Pin<Box<dyn std::future::Future<Output = Result<Value, EvalError>> + 'e>> {
        Box::pin(async move {
            // Clone the op config so we hold no borrow of `self.config` across the
            // `&mut self` operand evaluations below.
            let op_cfg = self
                .config
                .operators
                .values()
                .find(|configured| configured.op == op)
                .ok_or_else(|| EvalError::UnknownOperator(op.to_owned()))?
                .clone();

            let (operands, grouped) = if operand_exprs.is_empty() {
                let popped = match op_cfg.arity {
                    Arity::Exact(k) => self.stack.pop_n(k as usize).ok_or_else(|| {
                        EvalError::Stack(format!("`{op}` needs {k} value(s) on the stack to pop"))
                    })?,
                    Arity::Variadic => self.stack.pop_all(),
                };
                let grouped = vec![false; popped.len()];
                (popped, grouped)
            } else {
                let grouped: Vec<bool> = operand_exprs
                    .iter()
                    .map(|expr| matches!(expr, Expr::Group(_)))
                    .collect();
                let mut operands = Vec::with_capacity(operand_exprs.len());
                for expr in operand_exprs {
                    operands.push(self.eval_async(expr, realiser).await?);
                }
                if op_cfg.arity == Arity::Variadic {
                    spread_lists(operands, grouped)
                } else {
                    (operands, grouped)
                }
            };

            // do-N-times (`{form}_N`, bd-5dd86f): a Form first operand of `_`
            // composes the form N times (sync — no realiser await needed).
            if op == "_" && matches!(operands.first(), Some(Value::Form(_))) {
                return self.compose_form(&operands);
            }

            // Glyph operators (bd-44c294), async: same pre-coercion dispatch as
            // the sync path, through the async realiser (a form/builtin op may
            // realise llm ops per item).
            if let Some(builtin) = op_cfg.builtin.clone() {
                let (body, items) = builtin_op_operands(&builtin, &operands)?;
                return self
                    .run_higher_order_async(builtin, body, items, realiser)
                    .await;
            }
            if let Some(form_src) = op_cfg.form.clone() {
                let body = self.parse_op_form(&form_src)?;
                self.arg_frames.push(operands.clone());
                let result = self.eval_async(&body, realiser).await;
                self.arg_frames.pop();
                return result;
            }
            // Det-mode-only `det:` form (bd-6f9c1d), async twin.
            if self.mode == Mode::Det {
                if let Some(det_src) = op_cfg.det.clone() {
                    let body = self.parse_op_form(&det_src)?;
                    self.arg_frames.push(operands.clone());
                    let result = self.eval_async(&body, realiser).await;
                    self.arg_frames.pop();
                    return result;
                }
            }

            let sep = self.sep();
            let mut coerced = Vec::with_capacity(operands.len());
            for value in &operands {
                coerced.push(
                    coerce_operand_async(
                        value,
                        op_cfg.operands,
                        &sep,
                        self.mode,
                        self.config,
                        realiser,
                    )
                    .await?,
                );
            }
            realise_async(
                op,
                &op_cfg,
                &coerced,
                &grouped,
                &sep,
                self.mode,
                self.config,
                realiser,
            )
            .await
        })
    }

    /// Async mirror of [`step_once`](Self::step_once) (bd-9dd22d): reduce the
    /// leftmost-innermost redex by one step, `await`ing the injected realiser at
    /// effectful redexes. Powers [`step_async`] (the wasm step view).
    async fn step_once_async<R: crate::realiser::Realiser>(
        &mut self,
        expr: &Expr,
        realiser: &R,
    ) -> Result<Step, EvalError> {
        if let Some(value) = as_value(expr) {
            return Ok(Step::Done(value));
        }
        Ok(Step::Reduced(self.reduce_async(expr, realiser).await?))
    }

    /// Async mirror of [`reduce`](Self::reduce): one reduction that `await`s the
    /// realiser when the redex is an all-operands-value effectful
    /// [`Expr::Apply`] (via [`eval_apply_async`](Self::eval_apply_async)). Pure
    /// reductions (reads, literals, assignment write-through) reuse the sync
    /// [`eval`](Self::eval); deterministic reductions never await.
    fn reduce_async<'e, R: crate::realiser::Realiser>(
        &'e mut self,
        expr: &'e Expr,
        realiser: &'e R,
    ) -> std::pin::Pin<Box<dyn std::future::Future<Output = Result<Expr, EvalError>> + 'e>> {
        Box::pin(async move {
            match expr {
                // Reads / interpolating quotes resolve to a value in one step (pure).
                Expr::ContextRead(_)
                | Expr::StackPeek
                | Expr::StackIndex(_)
                | Expr::Message { .. }
                | Expr::MessageRange { .. }
                | Expr::Quoted {
                    interpolate: true, ..
                }
                | Expr::Quote(_) => Ok(Expr::Value(self.eval(expr)?)),
                Expr::FormApply { .. } => Ok(Expr::Value(self.eval_async(expr, realiser).await?)),
                Expr::Group(inner) => Ok(Expr::Group(Box::new(
                    self.reduce_async(inner, realiser).await?,
                ))),
                Expr::Serial(inner) => Ok(Expr::Serial(Box::new(
                    self.reduce_async(inner, realiser).await?,
                ))),
                Expr::List(items) => {
                    let mut items = items.clone();
                    if let Some(i) = items.iter().position(|it| as_value(it).is_none()) {
                        let item = items[i].clone();
                        items[i] = self.reduce_async(&item, realiser).await?;
                    }
                    Ok(Expr::List(items))
                }
                Expr::Assign { key, value } => {
                    if as_value(value).is_some() {
                        Ok(Expr::Value(self.eval(expr)?))
                    } else {
                        Ok(Expr::Assign {
                            key: key.clone(),
                            value: Box::new(self.reduce_async(value, realiser).await?),
                        })
                    }
                }
                Expr::Apply {
                    op,
                    fixity,
                    operands,
                } => {
                    if let Some(i) = operands.iter().position(|o| as_value(o).is_none()) {
                        let mut operands = operands.clone();
                        let operand = operands[i].clone();
                        operands[i] = self.reduce_async(&operand, realiser).await?;
                        Ok(Expr::Apply {
                            op: op.clone(),
                            fixity: *fixity,
                            operands,
                        })
                    } else {
                        // All operands are values: realise this node (may await).
                        Ok(Expr::Value(
                            self.eval_apply_async(op, operands, realiser).await?,
                        ))
                    }
                }
                Expr::Value(_) | Expr::Bare(_) | Expr::Number(_) | Expr::Quoted { .. } => {
                    Ok(Expr::Value(self.eval(expr)?))
                }
            }
        })
    }
}

/// Coerce one operand to `target`: deterministic first, then (in llm mode) the
/// type's `model` + `prompt` fallback from `config.types` (SPEC §Types, bd-ba9f85).
/// Renders the value, asks the model to interpret it as the target type, and
/// parses the model's answer deterministically.
fn coerce_operand(
    value: &Value,
    target: TypeName,
    sep: &str,
    mode: Mode,
    config: &Config,
) -> Result<Value, EvalError> {
    if let Some(coerced) = value.coerce_deterministic(target, sep) {
        return Ok(coerced);
    }
    if matches!(mode, Mode::Llm) {
        if let Some(type_cfg) = config.types.get(target.as_str()) {
            if let Some(prompt) = type_cfg.prompt.as_deref() {
                let rendered = value.render(sep);
                let answer = crate::llm::realise_llm(
                    type_cfg.model.as_deref(),
                    prompt,
                    std::slice::from_ref(&rendered),
                    config,
                    None,
                    |name| std::env::var(name).ok(),
                )
                .map_err(|error| EvalError::Llm(error.to_string()))?;
                return Value::string(answer)
                    .coerce(target, sep)
                    .map_err(EvalError::Coerce);
            }
        }
    }
    value.coerce(target, sep).map_err(EvalError::Coerce)
}

/// Resolve + run an operator's realisation (bd-d58371). Order (SPEC §Modes):
/// `command:` / `reduce:` (always deterministic) → `det` mode `template:` /
/// `join:` → `llm` mode `model:` + `prompt:`. Free so both the sequential and
/// the concurrent operand paths (bd-780dbf) share it.
fn realise(
    op: &str,
    op_cfg: &OperatorConfig,
    operands: &[Value],
    grouped: &[bool],
    sep: &str,
    mode: Mode,
    config: &Config,
) -> Result<Value, EvalError> {
    if let Some(command) = &op_cfg.command {
        return realise_command(command, operands, sep);
    }
    if let Some(reduce_op) = op_cfg.reduce {
        // Numeric reduction ignores grouping (it operates on numbers).
        return Ok(crate::realise::reduce(reduce_op, operands)?);
    }
    match mode {
        Mode::Det => {
            let rendered = parenthesise_grouped(operands, grouped, sep);
            if let Some(template) = &op_cfg.template {
                Ok(crate::realise::template(template, &rendered, sep))
            } else if let Some(separator) = &op_cfg.join {
                Ok(crate::realise::join(&rendered, separator, sep))
            } else {
                Err(EvalError::Unsupported(format!(
                    "operator `{op}` has no deterministic (template/join/reduce) realisation"
                )))
            }
        }
        Mode::Llm => {
            // llm realisation (bd-3573aa): resolve the model, fill the prompt
            // from the operands, call the backend via aur-2's llm::realise_llm
            // seam (bd-dc3c72), and wrap the result.
            let Some(prompt) = op_cfg.prompt.as_deref() else {
                return Err(EvalError::Unsupported(format!(
                    "operator `{op}` has no llm realisation (needs a `prompt:`)"
                )));
            };
            // Operand text feeds the model's prompt; grouped operands keep their
            // parens (SPEC: preserved in output).
            let rendered = parenthesise_grouped(operands, grouped, sep);
            let args: Vec<String> = rendered.iter().map(|value| value.render(sep)).collect();
            crate::llm::realise_llm(
                op_cfg.model.as_deref(),
                prompt,
                &args,
                config,
                None,
                |name| std::env::var(name).ok(),
            )
            .map(Value::string)
            .map_err(|error| EvalError::Llm(error.to_string()))
        }
    }
}

/// Async mirror of [`realise`] (bd-bec201): deterministic realisation
/// (`reduce:` / `template:` / `join:`) is pure and identical; the effectful
/// `command:` and `llm` branches `await` the injected [`crate::realiser::Realiser`]
/// instead of calling the native backend directly.
#[allow(clippy::too_many_arguments)]
async fn realise_async<R: crate::realiser::Realiser>(
    op: &str,
    op_cfg: &OperatorConfig,
    operands: &[Value],
    grouped: &[bool],
    sep: &str,
    mode: Mode,
    config: &Config,
    realiser: &R,
) -> Result<Value, EvalError> {
    if let Some(command) = &op_cfg.command {
        let args: Vec<String> = operands.iter().map(|value| value.render(sep)).collect();
        return realiser
            .command(command, &args)
            .await
            .map(Value::string)
            .map_err(|error| match error {
                crate::llm::RealiseError::OperatorCommand(message) => EvalError::Command(message),
                other => EvalError::Command(other.to_string()),
            });
    }
    if let Some(reduce_op) = op_cfg.reduce {
        return Ok(crate::realise::reduce(reduce_op, operands)?);
    }
    match mode {
        Mode::Det => {
            let rendered = parenthesise_grouped(operands, grouped, sep);
            if let Some(template) = &op_cfg.template {
                Ok(crate::realise::template(template, &rendered, sep))
            } else if let Some(separator) = &op_cfg.join {
                Ok(crate::realise::join(&rendered, separator, sep))
            } else {
                Err(EvalError::Unsupported(format!(
                    "operator `{op}` has no deterministic (template/join/reduce) realisation"
                )))
            }
        }
        Mode::Llm => {
            let Some(prompt) = op_cfg.prompt.as_deref() else {
                return Err(EvalError::Unsupported(format!(
                    "operator `{op}` has no llm realisation (needs a `prompt:`)"
                )));
            };
            let rendered = parenthesise_grouped(operands, grouped, sep);
            let args: Vec<String> = rendered.iter().map(|value| value.render(sep)).collect();
            let call = crate::llm::assemble_llm(
                op_cfg.model.as_deref(),
                prompt,
                &args,
                config,
                None,
                |name| std::env::var(name).ok(),
            )
            .map_err(|error| EvalError::Llm(error.to_string()))?;
            realiser
                .llm(&call)
                .await
                // Strip any `<text>…</text>` wrapper the model echoed, at the shared
                // realiser seam so EVERY backend (incl. the browser JsRealiser, which
                // returns raw fetched text) is guarded, not just native run_llm (bd-cb761e).
                .map(|s| Value::string(crate::llm::strip_text_tags(&s)))
                .map_err(|error| EvalError::Llm(error.to_string()))
        }
    }
}

/// Async mirror of [`coerce_operand`]: deterministic coercion is pure; the
/// llm-mode type-coercion fallback `await`s the injected realiser.
async fn coerce_operand_async<R: crate::realiser::Realiser>(
    value: &Value,
    target: TypeName,
    sep: &str,
    mode: Mode,
    config: &Config,
    realiser: &R,
) -> Result<Value, EvalError> {
    if let Some(coerced) = value.coerce_deterministic(target, sep) {
        return Ok(coerced);
    }
    if matches!(mode, Mode::Llm) {
        if let Some(type_cfg) = config.types.get(target.as_str()) {
            if let Some(prompt) = type_cfg.prompt.as_deref() {
                let rendered = value.render(sep);
                let call = crate::llm::assemble_llm(
                    type_cfg.model.as_deref(),
                    prompt,
                    std::slice::from_ref(&rendered),
                    config,
                    None,
                    |name| std::env::var(name).ok(),
                )
                .map_err(|error| EvalError::Llm(error.to_string()))?;
                let answer = realiser
                    .llm(&call)
                    .await
                    .map_err(|error| EvalError::Llm(error.to_string()))?;
                // Same seam-level wrapper strip for the llm type-coercion path (bd-cb761e).
                let answer = crate::llm::strip_text_tags(&answer);
                return Value::string(answer)
                    .coerce(target, sep)
                    .map_err(EvalError::Coerce);
            }
        }
    }
    value.coerce(target, sep).map_err(EvalError::Coerce)
}

/// Parse and evaluate `expr` through the injected [`crate::realiser::Realiser`]
/// (bd-bec201, nlir-wasm P0): the async, SERIAL counterpart to [`evaluate`]. The
/// browser drives this via `wasm-bindgen-futures` with a JS-callback realiser;
/// native callers pass [`crate::realiser::NativeRealiser`]. `config` is already
/// parsed (the wasm crate parses `config_json` -> [`Config`] at its boundary, so
/// this entry stays format-agnostic). Deterministic evaluation never awaits.
///
/// # Errors
/// Returns [`EvalError`] on a lex/parse failure or any evaluation error.
pub async fn evaluate_async<R: crate::realiser::Realiser>(
    expr: &str,
    config: &Config,
    context: &mut Context,
    mode: Mode,
    realiser: &R,
) -> Result<Value, EvalError> {
    let sigils = crate::config::operator_sigils(config);
    let tokens = lexer::tokenize(expr, &sigils).map_err(|error| {
        EvalError::Lex(format!("{error}\n{}", source_pointer(expr, error.position)))
    })?;
    let program = parser::parse_program(&tokens, &config.operators)
        .map_err(|error| EvalError::Parse(error.to_string()))?;
    let mut evaluator = Evaluator::new(config, context, mode);
    let mut last = None;
    for statement in &program.statements {
        let value = evaluator.eval_async(statement, realiser).await?;
        evaluator.stack.push(value.clone());
        last = Some(value);
    }
    last.ok_or(EvalError::EmptyProgram)
}

/// Parse `expr` and return its small-step reduction TRACE through the injected
/// [`crate::realiser::Realiser`] (bd-9dd22d): the async, serial counterpart to
/// [`step_trace`], for the wasm step view (P1 `step()` / P2 workspace). Each
/// entry is the rendered expression at that step (reduced nodes as «text»),
/// mapping 1:1 to the JS contract `step(...) -> {steps:[{expr}]}`. Deterministic
/// reductions never await; each effectful redex is one realiser call.
///
/// # Errors
/// Returns [`EvalError`] on a lex/parse failure or any error while reducing.
pub async fn step_async<R: crate::realiser::Realiser>(
    expr: &str,
    config: &Config,
    context: &mut Context,
    mode: Mode,
    realiser: &R,
) -> Result<Vec<String>, EvalError> {
    let mut steps = Vec::new();
    step_trace_streaming_async(expr, config, context, mode, realiser, |rendered| {
        steps.push(rendered.to_owned());
    })
    .await?;
    Ok(steps)
}

/// Async streaming twin of [`step_trace_streaming`] (bd-89eb89): the live-progress
/// source for llm mode, where each effectful redex is a slow realiser call, so
/// streaming each step as it resolves is the big win over batching to a `Vec`.
/// `on_step` fires with the initial statement then once per reduction, in order —
/// each effectful redex firing the moment its realisation completes inside the
/// per-step await loop (so a slow llm step streams live, not batched).
/// [`step_async`] is now a thin collector over it.
///
/// # Errors
/// Returns [`EvalError`] on a lex/parse failure or any error while reducing.
pub async fn step_trace_streaming_async<R: crate::realiser::Realiser>(
    expr: &str,
    config: &Config,
    context: &mut Context,
    mode: Mode,
    realiser: &R,
    mut on_step: impl FnMut(&str),
) -> Result<(), EvalError> {
    let sigils = crate::config::operator_sigils(config);
    let tokens = lexer::tokenize(expr, &sigils).map_err(|error| {
        EvalError::Lex(format!("{error}\n{}", source_pointer(expr, error.position)))
    })?;
    let program = parser::parse_program(&tokens, &config.operators)
        .map_err(|error| EvalError::Parse(error.to_string()))?;
    let mut evaluator = Evaluator::new(config, context, mode);
    for statement in &program.statements {
        let mut current = statement.clone();
        on_step(&current.render_step());
        while let Step::Reduced(next) = evaluator.step_once_async(&current, realiser).await? {
            current = next;
            on_step(&current.render_step());
        }
        if let Some(value) = as_value(&current) {
            evaluator.stack.push(value);
        }
    }
    Ok(())
}

/// [`realise`] with per-run memoisation (bd-1d078c) shared across
/// concurrently-evaluated operand subtrees via a `Mutex`-guarded cache. When
/// `cache_on` (`_cache`, default true), identical realisations — same
/// `(op, mode, model, grouping, operand-texts)` — are computed once and reused,
/// deduping repeated LLM/command subcalls (SPEC §Execution graph: caching).
///
/// Two truly-simultaneous identical subcalls on different threads may both miss
/// the cache and compute (in-flight dedup is not attempted); sequential repeats
/// are always deduped.
#[allow(clippy::too_many_arguments)]
fn realise_cached(
    op: &str,
    op_cfg: &OperatorConfig,
    operands: &[Value],
    grouped: &[bool],
    sep: &str,
    mode: Mode,
    config: &Config,
    cache_on: bool,
    cache: &std::sync::Mutex<std::collections::HashMap<String, Value>>,
) -> Result<Value, EvalError> {
    if !cache_on {
        return realise(op, op_cfg, operands, grouped, sep, mode, config);
    }
    let key = realise_cache_key(op, mode, op_cfg.model.as_deref(), operands, grouped, sep);
    // Serve a hit without holding the lock across the realisation.
    if let Some(cached) = cache
        .lock()
        .expect("realise cache mutex")
        .get(&key)
        .cloned()
    {
        return Ok(cached);
    }
    let result = realise(op, op_cfg, operands, grouped, sep, mode, config)?;
    cache
        .lock()
        .expect("realise cache mutex")
        .insert(key, result.clone());
    Ok(result)
}

/// Wrap grouped operands' rendered form in parentheses (SPEC: parens are
/// preserved in output), leaving ungrouped operands as-is for the string
/// realisations.
fn parenthesise_grouped(operands: &[Value], grouped: &[bool], sep: &str) -> Vec<Value> {
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

/// Run a `command:` realisation: operands are exposed to a `bash` subprocess as
/// the `NLIR_ARGS` array (SPEC `echo` operator), and its stdout is the result —
/// deterministic in both modes (bd-3c1e6d).
fn realise_command(command: &str, operands: &[Value], sep: &str) -> Result<Value, EvalError> {
    let args: Vec<String> = operands.iter().map(|value| value.render(sep)).collect();
    // The bash spawn lives in llm.rs (the native realiser body, shared with the
    // Realiser seam); preserve the historical EvalError::Command message text.
    crate::llm::run_operator_command(command, &args)
        .map(Value::string)
        .map_err(|error| match error {
            crate::llm::RealiseError::OperatorCommand(message) => EvalError::Command(message),
            other => EvalError::Command(other.to_string()),
        })
}

/// Whether an expression subtree can be evaluated concurrently with its
/// siblings (SPEC §Execution graph safety; bd-780dbf / bd-0d9f66). Safe iff it
/// only READS context + computes: no context write (`Expr::Assign`), no stack
/// access (`$` / `$N`), and no nullary operator (an `Apply` with no operands
/// pops the stack). Reads (`$name`, `^`) are fine because the parallel section
/// never writes context.
fn is_parallel_safe(expr: &Expr, config: &Config) -> bool {
    match expr {
        Expr::Bare(_) | Expr::Quoted { .. } | Expr::Number(_) | Expr::ContextRead(_) => true,
        Expr::StackPeek | Expr::StackIndex(_) | Expr::Assign { .. } => false,
        Expr::Message { index, .. } => is_parallel_safe(index, config),
        Expr::MessageRange { start, end, .. } => {
            is_parallel_safe(start, config) && is_parallel_safe(end, config)
        }
        Expr::Group(inner) | Expr::Serial(inner) => is_parallel_safe(inner, config),
        // A quoted form is inert data (its inner is not evaluated) — pure/safe.
        Expr::Quote(_) => true,
        // Form application evaluates a body (may read the stack / arg frame) —
        // not parallel-safe.
        Expr::FormApply { .. } => false,
        Expr::List(items) => items.iter().all(|e| is_parallel_safe(e, config)),
        // A nullary op (empty operands) pops the stack; a form:/builtin: glyph
        // operator (bd-44c294) applies a form / higher-order over an arg frame,
        // exactly like FormApply — neither is parallel-safe (the parallel operand
        // path is a free fn with no Evaluator arg-frame to bind $0/$1).
        Expr::Apply { op, operands, .. } => {
            if operands.is_empty() {
                return false;
            }
            if let Some(cfg) = config.operators.values().find(|c| c.op == *op) {
                if cfg.form.is_some() || cfg.builtin.is_some() {
                    return false;
                }
            }
            operands.iter().all(|e| is_parallel_safe(e, config))
        }
        // A reduced value is pure (no context write, no stack, no op).
        Expr::Value(_) => true,
    }
}

/// Read-only evaluation of a parallel-safe subtree (see [`is_parallel_safe`]),
/// sharing only `&Config`, `&Context`, and the `Mutex`-guarded cache, so it runs
/// on a scoped thread (bd-780dbf). It mirrors [`Evaluator::eval`] for the pure
/// subset (no stack, no context writes); excluded node kinds are defensively
/// errored. A nested `Apply`'s operands evaluate sequentially here —
/// parallelisation happens only at the top level of each `Apply`, which bounds
/// total concurrency.
fn eval_parallel_safe(
    expr: &Expr,
    config: &Config,
    context: &Context,
    mode: Mode,
    cache_on: bool,
    cache: &std::sync::Mutex<std::collections::HashMap<String, Value>>,
) -> Result<Value, EvalError> {
    match expr {
        Expr::Bare(text) => Ok(Value::string(text.clone())),
        Expr::Quoted {
            content,
            interpolate,
        } => Ok(Value::string(if *interpolate {
            context.interpolate(content)
        } else {
            content.clone()
        })),
        Expr::Number(n) => Ok(Value::number(*n)),
        // A quoted form is inert data (its inner is not evaluated): a Value::Form
        // carrying the inner AST (bd-5dd86f).
        Expr::Quote(inner) => Ok(Value::form((**inner).clone())),
        Expr::ContextRead(name) => context
            .get(name)
            .map(|json| json_to_value_forms(json, config))
            .ok_or_else(|| EvalError::UnknownContextKey(name.to_owned())),
        Expr::Message { role, index } => {
            let sep = context.sep();
            let number = eval_parallel_safe(index, config, context, mode, cache_on, cache)?
                .coerce(TypeName::Number, &sep)?
                .as_number()
                .ok_or_else(|| {
                    EvalError::Unsupported("message index is not a number".to_owned())
                })?;
            #[allow(clippy::cast_possible_truncation)]
            let i = number.trunc() as i64;
            let view = MessageIndex::new(
                context.messages(),
                &config.context.messages.views,
                &config.context.messages.role_field,
                &config.context.messages.content_field,
            );
            view.content_at(*role, i)
                .map(Value::string)
                .ok_or(EvalError::NoMessage {
                    role: *role,
                    index: i,
                })
        }
        Expr::MessageRange { role, start, end } => {
            let sep = context.sep();
            let start_n = eval_parallel_safe(start, config, context, mode, cache_on, cache)?
                .coerce(TypeName::Number, &sep)?
                .as_number()
                .ok_or_else(|| {
                    EvalError::Unsupported("message index is not a number".to_owned())
                })?;
            let end_n = eval_parallel_safe(end, config, context, mode, cache_on, cache)?
                .coerce(TypeName::Number, &sep)?
                .as_number()
                .ok_or_else(|| {
                    EvalError::Unsupported("message index is not a number".to_owned())
                })?;
            #[allow(clippy::cast_possible_truncation)]
            let (start_i, end_i) = (start_n.trunc() as i64, end_n.trunc() as i64);
            let view = MessageIndex::new(
                context.messages(),
                &config.context.messages.views,
                &config.context.messages.role_field,
                &config.context.messages.content_field,
            );
            Ok(Value::string(view.range(*role, start_i, end_i, &sep)))
        }
        Expr::Group(inner) | Expr::Serial(inner) => {
            eval_parallel_safe(inner, config, context, mode, cache_on, cache)
        }
        Expr::List(items) => {
            let values = items
                .iter()
                .map(|item| eval_parallel_safe(item, config, context, mode, cache_on, cache))
                .collect::<Result<Vec<_>, _>>()?;
            Ok(Value::list(values))
        }
        // Form application is not run in the parallel-safe fast path (it evaluates
        // a body under an argument frame); is_parallel_safe returns false, so the
        // DAG scheduler evals it on the main path — defensive arm (bd-5dd86f).
        Expr::FormApply { .. } => Err(EvalError::Unsupported(
            "form application is not evaluated in the parallel-safe path".to_owned(),
        )),
        Expr::Apply { op, operands, .. } => {
            let op_cfg = config
                .operators
                .values()
                .find(|configured| configured.op == *op)
                .ok_or_else(|| EvalError::UnknownOperator((*op).to_owned()))?;
            let grouped: Vec<bool> = operands
                .iter()
                .map(|expr| matches!(expr, Expr::Group(_)))
                .collect();
            let mut values = Vec::with_capacity(operands.len());
            for operand in operands {
                values.push(eval_parallel_safe(
                    operand, config, context, mode, cache_on, cache,
                )?);
            }
            let (values, grouped) = if op_cfg.arity == Arity::Variadic {
                spread_lists(values, grouped)
            } else {
                (values, grouped)
            };
            let sep = context.sep();
            let coerced = values
                .iter()
                .map(|value| coerce_operand(value, op_cfg.operands, &sep, mode, config))
                .collect::<Result<Vec<_>, _>>()?;
            realise_cached(
                op, op_cfg, &coerced, &grouped, &sep, mode, config, cache_on, cache,
            )
        }
        // A value spliced in by step-through evaluation is already reduced.
        Expr::Value(value) => Ok(value.clone()),
        // is_parallel_safe excludes these; defensive.
        Expr::Assign { .. } | Expr::StackPeek | Expr::StackIndex(_) => Err(EvalError::Unsupported(
            "non-parallel-safe node reached the parallel eval path".to_owned(),
        )),
    }
}

/// Evaluate an operator's operand subtrees concurrently on scoped threads,
/// bounded by `parallelism` (SPEC §Execution graph; bd-780dbf). Callers must have
/// verified every operand [`is_parallel_safe`]. Results are returned in operand
/// order; the first error wins.
#[cfg(not(target_arch = "wasm32"))]
fn eval_operands_parallel(
    operand_exprs: &[Expr],
    config: &Config,
    context: &Context,
    mode: Mode,
    cache_on: bool,
    cache: &std::sync::Mutex<std::collections::HashMap<String, Value>>,
    parallelism: usize,
) -> Result<Vec<Value>, EvalError> {
    let mut results = Vec::with_capacity(operand_exprs.len());
    for chunk in operand_exprs.chunks(parallelism.max(1)) {
        let chunk_results: Vec<Result<Value, EvalError>> = std::thread::scope(|scope| {
            let handles: Vec<_> = chunk
                .iter()
                .map(|expr| {
                    scope.spawn(move || {
                        eval_parallel_safe(expr, config, context, mode, cache_on, cache)
                    })
                })
                .collect();
            handles
                .into_iter()
                .map(|handle| {
                    handle.join().unwrap_or_else(|_| {
                        Err(EvalError::Unsupported(
                            "evaluation thread panicked".to_owned(),
                        ))
                    })
                })
                .collect()
        });
        for result in chunk_results {
            results.push(result?);
        }
    }
    Ok(results)
}

/// wasm-serial scheduler fallback (nlir-wasm epic bd-360d0c): wasm32 has no
/// threads, and the execution-graph scheduler is orthogonal to the realiser
/// seam, so operands evaluate serially in operand order. Same signature as the
/// native threaded version so the caller is target-agnostic; `parallelism` is
/// accepted for parity but unused. The first error wins.
#[cfg(target_arch = "wasm32")]
fn eval_operands_parallel(
    operand_exprs: &[Expr],
    config: &Config,
    context: &Context,
    mode: Mode,
    cache_on: bool,
    cache: &std::sync::Mutex<std::collections::HashMap<String, Value>>,
    parallelism: usize,
) -> Result<Vec<Value>, EvalError> {
    let _ = parallelism;
    let mut results = Vec::with_capacity(operand_exprs.len());
    for expr in operand_exprs {
        results.push(eval_parallel_safe(
            expr, config, context, mode, cache_on, cache,
        )?);
    }
    Ok(results)
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
        // A form persists as a TAGGED JSON object carrying its body source, so
        // it round-trips back to a Value::Form on read (bd-5dd86f) — this is what
        // makes named lambdas/macros work (`f={form};$f%args`). The read side
        // (`Evaluator::json_to_value_forms`) reparses the source with the config
        // grammar.
        Value::Form(inner) => {
            let mut map = serde_json::Map::new();
            map.insert(FORM_TAG.to_owned(), Json::String(inner.render()));
            Json::Object(map)
        }
    }
}

/// The context-JSON key tagging a persisted [`Value::Form`] (bd-5dd86f), so an
/// assigned form round-trips back to a form on read rather than a bare string.
const FORM_TAG: &str = "__nlir_form__";

/// If `json` is a tagged persisted-form object (`{FORM_TAG: "<source>"}`),
/// return the carried body source.
fn form_tag_source(json: &Json) -> Option<&str> {
    match json {
        Json::Object(map) if map.len() == 1 => map.get(FORM_TAG).and_then(Json::as_str),
        _ => None,
    }
}

/// Convert a stored context JSON value to a [`Value`], reconstructing a
/// [`Value::Form`] from the tagged persisted-form object (bd-5dd86f) by
/// reparsing its source with the config grammar; all other JSON falls through to
/// [`json_to_value`]. This is what lets a named form round-trip
/// (`f={form};$f%args`).
fn json_to_value_forms(json: &Json, config: &Config) -> Value {
    if let Some(source) = form_tag_source(json) {
        if let Some(expr) = parse_stored_form(source, config) {
            return Value::form(expr);
        }
    }
    json_to_value(json)
}

/// Reparse a persisted form's body source into its [`Expr`] using the config's
/// operator grammar. `None` if it does not tokenise/parse (a corrupt/foreign
/// store) — then it reads back as a plain string.
fn parse_stored_form(source: &str, config: &Config) -> Option<Expr> {
    let sigils = crate::config::operator_sigils(config);
    let tokens = crate::lexer::tokenize(source, &sigils).ok()?;
    let program = crate::parser::parse_program(&tokens, &config.operators).ok()?;
    program.statements.into_iter().next()
}

/// Truthiness for `$filter` (bd-44c294 family): a predicate body's verdict keeps
/// the item when truthy. `Bool` is itself; `Number` is nonzero; `List` is
/// non-empty; a `Form` is truthy; a `String` is truthy unless empty or `false`
/// (case-insensitive). Filter-local — the global coercion rules stay strict.
fn value_is_truthy(v: &Value) -> bool {
    match v {
        Value::Bool(b) => *b,
        Value::Number(n) => *n != 0.0,
        Value::List(items) => !items.is_empty(),
        Value::Form(_) => true,
        Value::String(s) => {
            let t = s.trim();
            if t.is_empty() || t.eq_ignore_ascii_case("false") {
                false
            } else if let Ok(n) = t.parse::<f64>() {
                // arg-frame reads render items to text, so a numeric item arrives
                // as its string — use numeric truthiness (`"0"` is falsy).
                n != 0.0
            } else {
                true
            }
        }
    }
}

/// Build a `$builtin` arity error with the expected operand shape.
fn builtin_arity_err(name: &str, shape: &str, got: usize) -> EvalError {
    EvalError::Unsupported(format!("`${name}` takes {shape}; got {got} argument(s)"))
}

/// A value as a list of items: a [`Value::List`] spreads, anything else is a
/// singleton. Shared by the value builtins (`$nth`/`$sort`).
fn as_items(v: Value) -> Vec<Value> {
    match v {
        Value::List(items) => items,
        other => vec![other],
    }
}

/// Sort values ascending (`$sort`): numeric order when every item renders as a
/// number, else lexicographic on the rendered text. Total + deterministic.
fn sort_values(mut items: Vec<Value>, sep: &str) -> Vec<Value> {
    let numeric = |v: &Value| v.render(sep).trim().parse::<f64>().ok();
    if items.iter().all(|v| numeric(v).is_some()) {
        items.sort_by(|a, b| {
            numeric(a)
                .unwrap_or(0.0)
                .partial_cmp(&numeric(b).unwrap_or(0.0))
                .unwrap_or(std::cmp::Ordering::Equal)
        });
    } else {
        items.sort_by_key(|v| v.render(sep));
    }
    items
}

/// Resolve a `$nth` index against a list length: 0-based, negative counts from
/// the end (`-1` = last). Errors on a non-integer or out-of-range index.
fn resolve_nth(index: &Value, len: usize, sep: &str) -> Result<usize, EvalError> {
    let raw = index.render(sep);
    let i = raw.trim().parse::<i64>().map_err(|_| {
        EvalError::Unsupported(format!(
            "`$nth` index must be an integer, got `{}`",
            raw.trim()
        ))
    })?;
    let len_i = len as i64;
    let resolved = if i < 0 { len_i + i } else { i };
    if resolved < 0 || resolved >= len_i {
        return Err(EvalError::Unsupported(format!(
            "`$nth` index {i} out of range for a {len}-element list"
        )));
    }
    Ok(resolved as usize)
}

/// Extract the `(form-body, items)` for a `builtin:` map/fold glyph operator from
/// its two already-evaluated operands (bd-44c294): first must be a `{…}` form, the
/// second a list (a lone non-list value becomes a one-element list).
fn builtin_op_operands(name: &str, operands: &[Value]) -> Result<(Expr, Vec<Value>), EvalError> {
    if operands.len() != 2 {
        return Err(EvalError::Unsupported(format!(
            "`{name}` operator takes (form, list); got {} operand(s)",
            operands.len()
        )));
    }
    let body = match &operands[0] {
        Value::Form(inner) => (**inner).clone(),
        _ => {
            return Err(EvalError::Unsupported(format!(
                "`{name}` operator's first operand must be a {{…}} form"
            )));
        }
    };
    let items = match &operands[1] {
        Value::List(items) => items.clone(),
        other => vec![other.clone()],
    };
    Ok((body, items))
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

    /// Like [`det`] but forces sequential evaluation (`parallelism = 1`), so the
    /// per-run cache deduplicates identical subcalls (two truly-concurrent
    /// identical subcalls may both miss the cache and compute).
    fn det_seq(expr: &str) -> String {
        let mut cfg = config();
        cfg.defaults.parallelism = 1;
        let mut ctx = Context::empty(&cfg.context);
        let value = evaluate(expr, &cfg, &mut ctx, Mode::Det)
            .unwrap_or_else(|e| panic!("eval `{expr}`: {e}"));
        value.render(&ctx.sep())
    }

    #[test]
    fn form_application_binds_positional_args() {
        // `%` applies a form, binding $0/$1/… to the evaluated args (bd-5dd86f).
        assert_eq!(det("{$0+1}%5"), "6"); // single arg
        assert_eq!(det("{$0+$1}%(2,3)"), "5"); // tuple args
        assert_eq!(det("{$0+$1}%[2,3]"), "5"); // list args (spreads like the tuple)
    }

    #[test]
    fn form_application_arg_frame_shadows_stack() {
        // Argument-frame hygiene: inside a form `$0` is the ARG, not the stack
        // top — `9;{$0}%7` -> 7, not 9 (bd-5dd86f).
        assert_eq!(det("9;{$0}%7"), "7");
    }

    #[test]
    fn applying_a_non_form_is_an_error() {
        let cfg = config();
        let mut ctx = Context::empty(&cfg.context);
        assert!(evaluate("5%3", &cfg, &mut ctx, Mode::Det).is_err());
    }

    #[test]
    fn named_form_round_trips_through_context() {
        // A form assigned to a name round-trips through context persistence and
        // applies as a form — named lambdas/macros `f={…};$f%args` (bd-5dd86f).
        assert_eq!(det("f={$0+$1};$f%(2,3)"), "5");
        assert_eq!(det("sq={$0*$0};$sq%5"), "25");
        // A plain assigned string still reads back as a string (only the tagged
        // form object reconstructs to a Value::Form).
        assert_eq!(det("k=hello;$k"), "hello");
    }

    #[test]
    fn do_n_times_composes_a_form() {
        // `{form}_N` composes the form N times (do-N-times, bd-5dd86f): the `_`
        // repeat operator lifted from text-repeat to form-compose. Apply binds
        // tighter than `_`, so the compose needs parens before `%`.
        assert_eq!(det("({$0+1}_3)%5"), "8"); // +1 three times: 5->6->7->8
        assert_eq!(det("({$0*2}_2)%3"), "12"); // *2 twice: 3->6->12
        assert_eq!(det("({$0+1}_0)%5"), "5"); // N=0 is the identity form
        // A COMPOSED form round-trips through context persistence (it renders
        // with braces, not an `«…»` value splice) — named do-N `g=({f}_N);$g%x`.
        assert_eq!(det("g=({$0+1}_3);$g%5"), "8");
        // `_` on plain text still repeats text (not lifted).
        assert_eq!(det("x_3"), "x x x");
    }

    #[test]
    fn llm_mode_coerces_operands_via_type_model() {
        // In llm mode, a non-numeric operand is coerced through the type's
        // model+prompt fallback (bd-ba9f85). A command model keeps it offline:
        // `printf 5` returns 5 for any input, so 'five'+'five' -> 5+5 -> 10.
        let yaml = r##"
types:
  number:
    model: numify
    prompt: "as a number: %"
models:
  numify:
    type: command
    format: text
    command: 'printf 5'
operators:
  add: { op: "+", arity: ">0", fixity: mixfix, operands: number, result: number, reduce: add }
"##;
        let cfg = config::parse_str(yaml, Path::new("coerce.yaml")).expect("valid config");
        let mut ctx = Context::empty(&cfg.context);
        let out = evaluate("'five'+'five'", &cfg, &mut ctx, Mode::Llm).expect("llm coercion");
        assert_eq!(out.render(&ctx.sep()), "10");
        // det mode has no model fallback: the same expression is a coercion error.
        let mut ctx = Context::empty(&cfg.context);
        assert!(evaluate("'five'+'five'", &cfg, &mut ctx, Mode::Det).is_err());

        // The async entry (bd-bec201) reaches the SAME command backend through
        // the injected NativeRealiser (coerce_operand_async -> realiser.llm):
        // 'five'+'five' -> 5+5 -> 10, identical to the sync path.
        use crate::realiser::{NativeRealiser, block_on_ready};
        let mut ctx = Context::empty(&cfg.context);
        let out = block_on_ready(evaluate_async(
            "'five'+'five'",
            &cfg,
            &mut ctx,
            Mode::Llm,
            &NativeRealiser,
        ))
        .expect("async llm coercion");
        assert_eq!(out.render(&ctx.sep()), "10");
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
        // bd-1d078c: with `_cache` on (default) and SEQUENTIAL eval, two
        // identical realisations (`~x` via a random command) are computed once
        // and reused, so both halves of the join match.
        let out = det_seq("~x&~x");
        let parts: Vec<&str> = out.split(" and ").collect();
        assert_eq!(parts.len(), 2, "expected a two-part join, got {out:?}");
        assert_eq!(
            parts[0], parts[1],
            "identical cached subcalls must return the same value, got {out:?}"
        );
    }

    #[test]
    fn cache_disabled_reruns_each_subcall() {
        // bd-1d078c: with `_cache=false` (and sequential eval), identical
        // subcalls are NOT deduped, so two random commands differ. Retry to
        // avoid a rare 6-byte nonce clash.
        let differ = (0..8).any(|_| {
            let out = det_seq("_cache=false;~x&~x");
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
    fn independent_operands_evaluate_concurrently_and_correctly() {
        // bd-780dbf: with parallelism > 1 (default 8), a variadic op's independent
        // operands evaluate on scoped threads; the result is identical to
        // sequential eval (concurrency is transparent).
        assert_eq!(
            det("#a&#b&#c"),
            "subject of a and subject of b and subject of c"
        );
        // Concurrent `command:` operands (two bash subprocesses) also compose
        // correctly and in order. Grouping pins each `_` echo as a `&` operand;
        // grouped operands keep their parens in the output.
        assert_eq!(det("(xxx_2)&(yyy_3)"), "(xxx xxx) and (yyy yyy yyy)");
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
    fn message_range_joins_indexed_messages() {
        // M^N joins the role's messages start..end with _sep; prefix ^N still
        // reads a single message (bd-c3fc30).
        let cfg = config();
        let mut ctx = Context::empty(&cfg.context);
        let mut seed = Map::new();
        seed.insert(
            "_messages".to_owned(),
            json!([
                {"role": "assistant", "content": "one"},
                {"role": "assistant", "content": "two"},
                {"role": "assistant", "content": "three"}
            ]),
        );
        ctx.merge(seed);
        let out = evaluate("0^2", &cfg, &mut ctx, Mode::Det).expect("range eval");
        assert_eq!(out.render(&ctx.sep()), "one\ntwo\nthree");
        let out = evaluate("1^2", &cfg, &mut ctx, Mode::Det).expect("range eval");
        assert_eq!(out.render(&ctx.sep()), "two\nthree");
        // Prefix ^-1 still disambiguates as a single-message read.
        let out = evaluate("^-1", &cfg, &mut ctx, Mode::Det).expect("prefix eval");
        assert_eq!(out.render(&ctx.sep()), "three");
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
    fn step_trace_reduces_innermost_redex_first() {
        // Step-through (bd-9c366d): in the test config arithmetic is
        // left-associative equal-precedence, so `2+3*4` parses as `((2+3)*4)`;
        // the inner `2+3` reduces before the outer `*`, ending at the final
        // value. Reduced sub-expressions render in guillemets.
        let cfg = config();
        let mut ctx = Context::empty(&cfg.context);
        let steps = step_trace("2+3*4", &cfg, &mut ctx, Mode::Det).expect("step trace");
        assert_eq!(steps.first().map(String::as_str), Some("(2 + 3) * 4"));
        assert!(
            steps.iter().any(|s| s == "\u{ab}5\u{bb} * 4"),
            "expected an intermediate `\u{ab}5\u{bb} * 4` step, got {steps:?}"
        );
        assert_eq!(steps.last().map(String::as_str), Some("\u{ab}20\u{bb}"));
    }

    #[test]
    fn step_trace_of_a_literal_is_a_single_already_reduced_step() {
        // A literal is already a value: no reduction, just the rendered literal.
        let cfg = config();
        let mut ctx = Context::empty(&cfg.context);
        let steps = step_trace("'hi'", &cfg, &mut ctx, Mode::Det).expect("step trace");
        assert_eq!(steps, vec!["hi".to_owned()]);
    }

    #[test]
    fn step_trace_streaming_matches_batch_and_streams_each_step() {
        // bd-89eb89: the streaming form fires on_step per reduction (initial +
        // each step), and step_trace is now a thin collector over it, so the two
        // agree exactly. It streams incrementally (>= 2 steps for a reducible expr).
        let cfg = config();
        let mut ctx_batch = Context::empty(&cfg.context);
        let batch = step_trace("2+3*4", &cfg, &mut ctx_batch, Mode::Det).expect("batch");
        let mut ctx_stream = Context::empty(&cfg.context);
        let mut streamed = Vec::new();
        step_trace_streaming("2+3*4", &cfg, &mut ctx_stream, Mode::Det, |s| {
            streamed.push(s.to_owned());
        })
        .expect("stream");
        assert_eq!(batch, streamed);
        assert!(
            streamed.len() >= 2,
            "a reducible expr should stream multiple steps: {streamed:?}"
        );
    }

    #[test]
    fn step_trace_streaming_async_matches_sync_in_det_mode() {
        // The async streaming twin matches the sync stream when no realiser is hit
        // (det mode). NativeRealiser's futures are ready-on-first-poll.
        use crate::realiser::{NativeRealiser, block_on_ready};
        let cfg = config();
        let mut ctx_sync = Context::empty(&cfg.context);
        let sync = step_trace("2+3*4", &cfg, &mut ctx_sync, Mode::Det).expect("sync");
        let mut ctx_async = Context::empty(&cfg.context);
        let mut streamed = Vec::new();
        block_on_ready(step_trace_streaming_async(
            "2+3*4",
            &cfg,
            &mut ctx_async,
            Mode::Det,
            &NativeRealiser,
            |s| streamed.push(s.to_owned()),
        ))
        .expect("async stream");
        assert_eq!(sync, streamed);
    }

    #[test]
    fn step_frames_streaming_matches_batch() {
        // bd-89eb89: the streaming frame form fires on_frame per reduction (frame 0
        // + each step), and step_frames is now a thin collector over it, so the two
        // frame sequences are identical (byte-for-byte for animate()).
        let cfg = config();
        let mut ctx_batch = Context::empty(&cfg.context);
        let batch = step_frames("2+3*4", &cfg, &mut ctx_batch, Mode::Det).expect("batch frames");
        let mut ctx_stream = Context::empty(&cfg.context);
        let mut streamed = Vec::new();
        step_frames_streaming("2+3*4", &cfg, &mut ctx_stream, Mode::Det, |f| {
            streamed.push(f.clone());
        })
        .expect("stream frames");
        assert_eq!(batch, streamed);
        assert!(
            streamed.len() >= 2,
            "reducible expr streams multiple frames"
        );
    }

    #[test]
    fn map_fold_higher_order_builtins() {
        // bd-14af74: `$map%(f,list)` applies form `f` per item -> a list; `$fold`
        // reduces left-to-right ($0=acc, $1=item), seeded by the first element.
        let cfg = config();
        for (src, expected) in [
            ("$map%({$0*$0},[1,2,3])", "1\n4\n9"),
            ("$map%({$0+1},[1,2,3])", "2\n3\n4"),
            ("$fold%({$0+$1},[1,2,3,4])", "10"),
            ("$fold%({$0*$1},[1,2,3,4])", "24"),
        ] {
            let mut ctx = Context::empty(&cfg.context);
            let out = evaluate(src, &cfg, &mut ctx, Mode::Det).expect(src);
            assert_eq!(out.render(&ctx.sep()), expected, "for {src}");
        }
    }

    #[test]
    fn map_of_named_form_and_user_key_shadows_builtin() {
        let cfg = config();
        // A named form maps just like an inline one ($sq resolves to the form).
        let mut ctx = Context::empty(&cfg.context);
        let out = evaluate("sq={$0*$0};$map%($sq,[1,2,3])", &cfg, &mut ctx, Mode::Det)
            .expect("named map");
        assert_eq!(out.render(&ctx.sep()), "1\n4\n9");
        // A user-defined `map` context key WINS over the builtin (backward-compat):
        // $map then applies the user's form, not the map builtin.
        let mut ctx2 = Context::empty(&cfg.context);
        let out2 = evaluate("map={$0+100};$map%5", &cfg, &mut ctx2, Mode::Det).expect("user map");
        assert_eq!(out2.render(&ctx2.sep()), "105");
    }

    #[test]
    fn glyph_operators_form_and_builtin() {
        // bd-44c294: a `form:`-backed operator applies its form to operands
        // ($0,$1,…); a `builtin:`-backed operator dispatches map/fold. User picks
        // the (here multibyte) glyph in config — no core-sigil cost.
        let yaml = r##"
operators:
  sq:     { op: "□", arity: 1, fixity: prefix, form: "{$0*$0}" }
  add2:   { op: "⊕", arity: 2, fixity: infix,  form: "{$0+$1}" }
  mapop:  { op: "↦", arity: 2, fixity: infix,  builtin: map }
  foldop: { op: "⊘", arity: 2, fixity: infix,  builtin: fold }
  add: { op: "+", arity: ">0", fixity: mixfix, priority: 11, operands: number, result: number, reduce: add }
  mul: { op: "*", arity: ">0", fixity: mixfix, priority: 12, operands: number, result: number, reduce: mul }
"##;
        let cfg = config::parse_str(yaml, Path::new("g.yaml")).unwrap();
        let check = |src: &str, expected: &str| {
            let mut ctx = Context::empty(&cfg.context);
            let out = evaluate(src, &cfg, &mut ctx, Mode::Det).expect(src);
            assert_eq!(out.render(&ctx.sep()), expected, "for {src}");
        };
        check("□5", "25"); // form-op: square
        check("2⊕3", "5"); // form-op: add2 (infix)
        check("{$0*$0}↦[1,2,3]", "1\n4\n9"); // builtin map-op
        check("{$0+$1}⊘[1,2,3,4]", "10"); // builtin fold-op
    }

    #[test]
    fn glyph_operators_async_matches_sync() {
        // bd-44c294: the async eval path dispatches form/builtin glyph ops too
        // (so a form-op with llm sub-ops works); matches sync in det mode.
        use crate::realiser::{NativeRealiser, block_on_ready};
        let yaml = r##"
operators:
  sq:     { op: "□", arity: 1, fixity: prefix, form: "{$0*$0}" }
  mapop:  { op: "↦", arity: 2, fixity: infix,  builtin: map }
  foldop: { op: "⊘", arity: 2, fixity: infix,  builtin: fold }
  add: { op: "+", arity: ">0", fixity: mixfix, priority: 11, operands: number, result: number, reduce: add }
  mul: { op: "*", arity: ">0", fixity: mixfix, priority: 12, operands: number, result: number, reduce: mul }
"##;
        let cfg = config::parse_str(yaml, Path::new("g.yaml")).unwrap();
        for (src, expected) in [
            ("□5", "25"),
            ("{$0*$0}↦[1,2,3]", "1\n4\n9"),
            ("{$0+$1}⊘[1,2,3,4]", "10"),
        ] {
            let mut ctx = Context::empty(&cfg.context);
            let out = block_on_ready(evaluate_async(
                src,
                &cfg,
                &mut ctx,
                Mode::Det,
                &NativeRealiser,
            ))
            .expect(src);
            assert_eq!(out.render(&ctx.sep()), expected, "async {src}");
        }
    }

    #[test]
    fn glyph_operators_nest_under_parallel_ops() {
        // bd-44c294 regression (found by aur-0): a form:/builtin: glyph op used as
        // an OPERAND of a parallel (mixfix) op, or nested under another glyph op,
        // must still dispatch. The parallel operand path is a free fn with no
        // arg-frame, so glyph ops must route sequential (is_parallel_safe=false).
        let yaml = r##"
defaults:
  parallelism: 4
operators:
  sq:     { op: "□", arity: 1, fixity: prefix, form: "{$0*$0}" }
  mapop:  { op: "↦", arity: 2, fixity: infix,  builtin: map }
  foldop: { op: "⊘", arity: 2, fixity: infix,  builtin: fold }
  add: { op: "+", arity: ">0", fixity: mixfix, priority: 11, operands: number, result: number, reduce: add }
  mul: { op: "*", arity: ">0", fixity: mixfix, priority: 12, operands: number, result: number, reduce: mul }
"##;
        let cfg = config::parse_str(yaml, Path::new("g.yaml")).unwrap();
        let check = |src: &str, expected: &str| {
            let mut ctx = Context::empty(&cfg.context);
            let out = evaluate(src, &cfg, &mut ctx, Mode::Det).expect(src);
            assert_eq!(out.render(&ctx.sep()), expected, "for {src}");
        };
        check("□5+1", "26"); // form-op as parallel-op operand
        check("1+□5", "26");
        check("□5*2", "50");
        check("□5+□3", "34"); // two glyph ops as parallel operands
        check("{$0+$1}⊘({$0*$0}↦[1,2,3])", "14"); // builtin nested under builtin
    }

    #[test]
    fn scan_and_filter_higher_order_builtins() {
        // The catamorphism family beyond map/fold (aur-0 gap-ranking): scan =
        // running fold (J's `\`); filter = keep-if (APL compress). Word-builtins
        // ($scan/$filter), composable with map/fold, no new sigils.
        let yaml = r##"
operators:
  add: { op: "+", arity: ">0", fixity: mixfix, priority: 11, operands: number, result: number, reduce: add }
  mul: { op: "*", arity: ">0", fixity: mixfix, priority: 12, operands: number, result: number, reduce: mul }
"##;
        let cfg = config::parse_str(yaml, Path::new("sf.yaml")).unwrap();
        let check = |src: &str, expected: &str| {
            let mut ctx = Context::empty(&cfg.context);
            let out = evaluate(src, &cfg, &mut ctx, Mode::Det).expect(src);
            assert_eq!(out.render(&ctx.sep()), expected, "for {src}");
        };
        // scan: running fold — prefix sums.
        check("$scan%({$0+$1},[1,2,3,4])", "1\n3\n6\n10");
        // filter: keep truthy items (identity predicate over a bool list).
        check("$filter%({$0},[true,false,true,false])", "true\ntrue");
        // filter truthiness on numbers (0 = falsy, nonzero = truthy) + the trinity.
        check("$filter%({$0},[1,0,2,0,3])", "1\n2\n3");
        check(
            "$fold%({$0+$1},$map%({$0*$0},$filter%({$0},[1,2,3])))",
            "14",
        );
        // scan composes over a map result (running sum of squares).
        check("$scan%({$0+$1},$map%({$0*$0},[1,2,3]))", "1\n5\n14");
    }

    #[test]
    fn operator_trains_desugar_to_forms() {
        // aur-1's train grammar: an operator-only paren group is a tacit
        // composition FORM, applied via %. all-prefix = atop (compose R-to-L);
        // a 3-op infix-middle group = fork (two lenses on one input).
        let yaml = r##"
operators:
  sq:   { op: "□", arity: 1, fixity: prefix, form: "{$0*$0}" }
  inc:  { op: "†", arity: 1, fixity: prefix, form: "{$0+1}" }
  plus: { op: "⊕", arity: 2, fixity: infix,  priority: 11, operands: number, result: number, reduce: add }
  amp:  { op: "&", arity: ">0", fixity: mixfix, priority: 5, join: " & " }
  add:  { op: "+", arity: ">0", fixity: mixfix, priority: 11, operands: number, result: number, reduce: add }
  mul:  { op: "*", arity: ">0", fixity: mixfix, priority: 12, operands: number, result: number, reduce: mul }
"##;
        let cfg = config::parse_str(yaml, Path::new("t.yaml")).unwrap();
        let check = |src: &str, expected: &str| {
            let mut ctx = Context::empty(&cfg.context);
            let out = evaluate(src, &cfg, &mut ctx, Mode::Det).expect(src);
            assert_eq!(out.render(&ctx.sep()), expected, "for {src}");
        };
        // atop 2-train: (□ †) = {□(†($0))} — inc then square, R-to-L.
        check("(□ †)%5", "36"); // □(†(5)) = □(6) = 36
        // fork with INFIX combiner: (□ ⊕ †) = {(□$0) ⊕ (†$0)} — two lenses on one input.
        check("(□ ⊕ †)%5", "31"); // (□5) ⊕ (†5) = 25 ⊕ 6 = 31
        // fork with MIXFIX combiner (bd-57f470): `&`/`|` are mixfix, arity >0.
        check("(□ & †)%5", "25 & 6"); // (□5) & (†5) = 25 & 6 (join)
        // atop 3-chain (all prefix): (□ † □) = {□(†(□($0)))}.
        check("(□ † □)%2", "25"); // □(†(□2)) = □(†4) = □5 = 25
    }

    #[test]
    fn value_builtins_if_nth_sort() {
        // basics batch (docs/design/basics-primitives.md §3–4): value builtins
        // dispatched at % like map/fold, operating on evaluated values.
        let cfg = config::parse_str(
            "operators:\n  sub: { op: \"-\", arity: 2, fixity: infix, priority: 11, operands: number, result: number, reduce: sub }\n",
            Path::new("v.yaml"),
        )
        .unwrap();
        let check = |src: &str, expected: &str| {
            let mut ctx = Context::empty(&cfg.context);
            let out = evaluate(src, &cfg, &mut ctx, Mode::Det).expect(src);
            assert_eq!(out.render(&ctx.sep()), expected, "for {src}");
        };
        // $if — short-circuit ternary over a truthy cond.
        check("$if%(true,'yes','no')", "yes");
        check("$if%(false,'yes','no')", "no");
        // $nth — 0-based; negative counts from the end (signed literal parse).
        check("$nth%(1,[a,b,c])", "b");
        check("$nth%(0,[a,b,c])", "a");
        check("$nth%(-1,[a,b,c])", "c");
        // negative numeric literal parses as a signed number.
        check("-5", "-5");
        // $sort — numeric when all-numeric, else lexicographic.
        check("$sort%[3,1,2]", "1\n2\n3");
        check("$sort%[banana,apple,cherry]", "apple\nbanana\ncherry");
        // $contains — Bool containment predicate (filter/if conds + ~> det).
        check("$contains%('login page broken','broken')", "true");
        check("$contains%('all systems green','broken')", "false");
    }

    #[test]
    fn det_field_realises_bool_in_det_mode() {
        // A `det:` form (bd-6f9c1d) is a det-mode-only COMPUTED realisation: an
        // otherwise-llm op gets a real Bool in det mode (here via $contains),
        // unblocking the correctness-gate count idiom deterministically.
        let cfg = config::parse_str(
            "operators:\n  imp: { op: \"⊃\", arity: 2, fixity: infix, priority: 6, det: \"{$contains%($0,$1)}\" }\n  add: { op: \"+\", arity: \">0\", fixity: mixfix, priority: 11, operands: number, result: number, reduce: add }\n",
            Path::new("d.yaml"),
        )
        .unwrap();
        let check = |src: &str, expected: &str| {
            let mut ctx = Context::empty(&cfg.context);
            let out = evaluate(src, &cfg, &mut ctx, Mode::Det).expect(src);
            assert_eq!(out.render(&ctx.sep()), expected, "for {src}");
        };
        check("'the login page is broken' ⊃ 'broken'", "true");
        check("'all systems green' ⊃ 'broken'", "false");
        // count idiom over a det: bool op: how many contain 'e'? bed,red -> 2.
        check("$fold%({$0+$1},$map%({$0 ⊃ 'e'},['bed','cat','red']))", "2");
    }

    #[test]
    fn apply_is_right_associative() {
        // `%` is right-associative (bd-2f4d5e, Harry-greenlit): `f%g%x` = `f%(g%x)`,
        // the compositional reading. So bare `%`-chaining a builtin over another
        // builtin's result now composes instead of silently mis-parsing. Only bare
        // `%`-chaining is affected — parens/nesting/trains are unchanged.
        let cfg = config::parse_str(
            "operators:\n  mul: { op: \"*\", arity: \">0\", fixity: mixfix, priority: 12, operands: number, result: number, reduce: mul }\n",
            Path::new("ra.yaml"),
        )
        .unwrap();
        let check = |src: &str, expected: &str| {
            let mut ctx = Context::empty(&cfg.context);
            let out = evaluate(src, &cfg, &mut ctx, Mode::Det).expect(src);
            assert_eq!(out.render(&ctx.sep()), expected, "for {src}");
        };
        // bare `%`-chain now reads right: $sort%$map%(...) = $sort%($map%(...)).
        check("$sort%$map%({$0*$0},[3,1,2])", "1\n4\n9");
        // explicit parens still give the same result (unchanged).
        check("$sort%($map%({$0*$0},[3,1,2]))", "1\n4\n9");
    }

    #[test]
    fn stdin_seeds_the_stack_for_nullary_pop() {
        // $_stdin-on-stack + nullary-fallback (bd-9a3e7c, Harry's §6): the reserved
        // `_stdin` transient is seeded onto the premise stack, and an operator with
        // no operand pulls it — `echo text | nlir -e '»'`.
        let cfg = config::parse_str(
            "operators:\n  up: { op: \"»\", arity: 1, fixity: prefix, template: \"UP: %\" }\n",
            Path::new("s.yaml"),
        )
        .unwrap();
        // nullary `»` (no operand) pulls the seeded piped stdin off the stack.
        let mut ctx = Context::empty(&cfg.context);
        ctx.set_transient("_stdin", serde_json::json!("piped"));
        let out = evaluate("»", &cfg, &mut ctx, Mode::Det).unwrap();
        assert_eq!(out.render(&ctx.sep()), "UP: piped");
        // normal prefix parse is unchanged (operand present).
        let mut ctx1 = Context::empty(&cfg.context);
        let normal = evaluate("»'x'", &cfg, &mut ctx1, Mode::Det).unwrap();
        assert_eq!(normal.render(&ctx1.sep()), "UP: x");
        // no _stdin -> empty stack -> LOUD underflow error (not silent).
        let mut ctx2 = Context::empty(&cfg.context);
        assert!(evaluate("»", &cfg, &mut ctx2, Mode::Det).is_err());
    }

    #[test]
    fn evaluate_async_matches_sync_eval_in_det_mode() {
        // The async entry (bd-bec201) must produce identical results to the sync
        // path when no effectful realisation is reached. Driven with the
        // NativeRealiser (its futures are ready-on-first-poll) via block_on_ready.
        use crate::realiser::{NativeRealiser, block_on_ready};
        for src in ["2+3*4", "x='ship'; $x"] {
            let cfg = config();
            let mut ctx_sync = Context::empty(&cfg.context);
            let sync = evaluate(src, &cfg, &mut ctx_sync, Mode::Det).expect("sync eval");
            let mut ctx_async = Context::empty(&cfg.context);
            let asynced = block_on_ready(evaluate_async(
                src,
                &cfg,
                &mut ctx_async,
                Mode::Det,
                &NativeRealiser,
            ))
            .expect("async eval");
            assert_eq!(sync, asynced, "async/sync mismatch for `{src}`");
        }
    }

    #[test]
    fn step_async_matches_step_trace_in_det_mode() {
        // The async step trace (bd-9dd22d) must match sync step_trace when no
        // effectful reduction is reached. Driven with the NativeRealiser via
        // block_on_ready.
        use crate::realiser::{NativeRealiser, block_on_ready};
        for src in ["2+3*4", "x='ship'; $x"] {
            let cfg = config();
            let mut ctx_sync = Context::empty(&cfg.context);
            let sync = step_trace(src, &cfg, &mut ctx_sync, Mode::Det).expect("sync step_trace");
            let mut ctx_async = Context::empty(&cfg.context);
            let asynced = block_on_ready(step_async(
                src,
                &cfg,
                &mut ctx_async,
                Mode::Det,
                &NativeRealiser,
            ))
            .expect("async step");
            assert_eq!(sync, asynced, "async/sync step mismatch for `{src}`");
        }
    }

    #[test]
    fn step_frames_reduce_pow_to_a_single_value() {
        // 2**3**2 = 2**(3**2): inner ** reduces, then outer ** -> one Value node.
        let cfg = config();
        let mut ctx = Context::empty(&cfg.context);
        let frames = step_frames("2**3**2", &cfg, &mut ctx, Mode::Det).expect("frames");
        assert_eq!(frames.len(), 3, "initial + 2 reductions");
        assert!(frames[0].reduced.is_none());
        assert!(frames[1..].iter().all(|f| f.reduced.is_some()));
        let last = &frames.last().unwrap().graph;
        assert_eq!(last.nodes.len(), 1);
        assert_eq!(last.nodes[0].kind, crate::graph::NodeKind::Value);
    }

    #[test]
    fn step_frames_keep_binding_edges_until_consumed() {
        // k=2;[$k,$k]: the assign feeds both reads; the edges persist past the
        // assign's OWN reduction and drop only as each read is consumed (G2).
        use crate::graph::{EdgeKind, NodeId};
        let cfg = config();
        let mut ctx = Context::empty(&cfg.context);
        let frames = step_frames("k=2;[$k,$k]", &cfg, &mut ctx, Mode::Det).expect("frames");
        let bindings = |i: usize| frames[i].graph.edges_of(EdgeKind::Binding).count();
        assert_eq!(bindings(0), 2, "initial: assign feeds both reads");
        let after_assign = frames
            .iter()
            .position(|f| f.reduced.as_ref() == Some(&NodeId(vec![0])))
            .expect("a frame where the assign reduced");
        assert_eq!(
            bindings(after_assign),
            2,
            "bindings persist past the assign's own reduction"
        );
        assert_eq!(
            bindings(frames.len() - 1),
            0,
            "edges drop once both reads are consumed"
        );
    }

    #[test]
    fn step_frames_async_matches_sync_in_det_mode() {
        // The async frame source must match the sync one when no effectful
        // reduction is reached (NativeRealiser futures are ready-on-first-poll).
        use crate::realiser::{NativeRealiser, block_on_ready};
        for src in ["2**3**2", "k=2;[$k,$k]"] {
            let cfg = config();
            let mut ctx_sync = Context::empty(&cfg.context);
            let sync = step_frames(src, &cfg, &mut ctx_sync, Mode::Det).expect("sync frames");
            let mut ctx_async = Context::empty(&cfg.context);
            let asynced = block_on_ready(step_frames_async(
                src,
                &cfg,
                &mut ctx_async,
                Mode::Det,
                &NativeRealiser,
            ))
            .expect("async frames");
            assert_eq!(sync, asynced, "async/sync frame mismatch for `{src}`");
        }
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

    /// A browser-style mock realiser that echoes a fixed string (ignoring the
    /// call). Unlike [`crate::realiser::NativeRealiser`] (which strips via
    /// `run_llm`/`extract_result`), it returns raw text — so it exercises the
    /// shared realise_async seam strip (bd-cb761e).
    struct EchoRealiser(String);

    impl crate::realiser::Realiser for EchoRealiser {
        fn llm<'a>(&'a self, _call: &'a crate::llm::LlmCall) -> crate::realiser::RealiseFuture<'a> {
            let s = self.0.clone();
            Box::pin(async move { Ok(s) })
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
    fn async_seam_strips_echoed_text_tags_incl_nested() {
        // bd-cb761e: the browser realiser returns raw fetched text (no strip), so a
        // model that echoes the <text> input delimiter — and re-wraps across nested
        // ops (the !(!(…)) accumulation Harry caught) — must be stripped at the shared
        // realise_async seam, not just in the native run_llm path.
        let yaml = r##"
models:
  any: { type: command, format: text, command: "true" }
operators:
  neg: { op: "!", arity: 1, fixity: prefix, model: any, prompt: "negate: %" }
"##;
        let cfg = config::parse_str(yaml, Path::new("llm.yaml")).unwrap();
        let mut ctx = Context::empty(&cfg.context);
        let realiser = EchoRealiser("<text><text>flipped</text></text>".to_owned());
        use crate::realiser::block_on_ready;
        let out = block_on_ready(evaluate_async("!x", &cfg, &mut ctx, Mode::Llm, &realiser))
            .expect("async llm realisation");
        assert_eq!(out.render(&ctx.sep()), "flipped");
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
