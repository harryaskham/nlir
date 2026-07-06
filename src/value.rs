//! nlir runtime values (SPEC §Types & coercion).
//!
//! bd-700306: the typed value model. Evaluating a statement yields a [`Value`]
//! that is pushed onto the stack; the program result is the final value rendered
//! to stdout (SPEC §Mental model). Every value carries exactly one of the four
//! SPEC types — `string` / `number` / `bool` / `list` — reported as a
//! [`config::TypeName`](crate::config::TypeName), so operators that declare
//! `operands:` / `result:` types share one type vocabulary with the value model.
//!
//! This module is intentionally the *value model only*: it defines the
//! representation, its type tag, constructors/accessors, and the **deterministic
//! rendering** that turns a value into its canonical string form (used both for
//! program output and for the `→ string` coercion, e.g. `1+1` → `"2"`,
//! `list → string` joins with `_sep`). The full coercion machinery —
//! deterministic parses (`"1"`↔`1`, `"true"→bool`), the constrained LLM coercion
//! fallback, and the loud `list → number` errors — lands on top of this model in
//! the coercion beads (bd-456f12 / bd-ecb930 / bd-20df97).

use std::fmt;

use crate::config::TypeName;
use crate::parser::Expr;

/// Default list/range → text separator (SPEC `_sep`, default `"\n"`).
///
/// Rendering that does not have the runtime `_sep` in hand (for example
/// [`Value`]'s [`fmt::Display`]) falls back to this. Evaluation threads the
/// live `_sep` from context through [`Value::render`].
pub const DEFAULT_SEP: &str = "\n";

/// A runtime value in the nlir stack machine (SPEC §Types & coercion).
///
/// The four variants are the whole type system. `String` is the default type;
/// operators and coercions move values between the variants.
#[derive(Debug, Clone, PartialEq)]
pub enum Value {
    /// UTF-8 text — the default type.
    String(String),
    /// A number. nlir numbers are `f64`; integral values render without a
    /// fractional part (`2`, not `2.0`) so `1+1` → `"2"` on output.
    Number(f64),
    /// A boolean, rendered `"true"` / `"false"`.
    Bool(bool),
    /// An ordered list of values. Renders by joining each element's rendering
    /// with the active separator (`_sep`).
    List(Vec<Value>),
    /// A quoted form (`{…}`): an unevaluated [`Expr`] carried as a first-class
    /// value (code-as-data). Produced by evaluating an [`Expr::Quote`]; only the
    /// application operator (`%`) consumes it as *callable*. Every other operator
    /// sees its rendered inner source (the op×Form rule), so a form coerces to
    /// its source text in any non-form slot. Renders (output/Display) WITH braces
    /// — `{(2 + 3)}` — so it round-trips against [`Expr::Quote`].
    Form(Box<Expr>),
}

impl Value {
    /// Construct a [`Value::String`] from anything string-like.
    #[must_use]
    pub fn string(text: impl Into<String>) -> Self {
        Value::String(text.into())
    }

    /// Construct a [`Value::Number`].
    #[must_use]
    pub const fn number(n: f64) -> Self {
        Value::Number(n)
    }

    /// Construct a [`Value::Bool`].
    #[must_use]
    pub const fn bool(b: bool) -> Self {
        Value::Bool(b)
    }

    /// Construct a [`Value::List`] from a vector of values.
    #[must_use]
    pub const fn list(items: Vec<Value>) -> Self {
        Value::List(items)
    }

    /// Construct a [`Value::Form`] from an [`Expr`] (a quoted form / code-as-data).
    #[must_use]
    pub fn form(expr: Expr) -> Self {
        Value::Form(Box::new(expr))
    }

    /// The [`TypeName`] of this value — the shared type tag used by operator
    /// `operands:` / `result:` declarations and the coercion layer.
    #[must_use]
    pub const fn type_name(&self) -> TypeName {
        match self {
            Value::String(_) => TypeName::String,
            Value::Number(_) => TypeName::Number,
            Value::Bool(_) => TypeName::Bool,
            Value::List(_) => TypeName::List,
            Value::Form(_) => TypeName::Form,
        }
    }

    /// Whether this value is already of `type_name` (coercion step 1: values
    /// already the required type are used as-is).
    #[must_use]
    pub const fn is_type(&self, type_name: TypeName) -> bool {
        matches!(
            (self, type_name),
            (Value::String(_), TypeName::String)
                | (Value::Number(_), TypeName::Number)
                | (Value::Bool(_), TypeName::Bool)
                | (Value::List(_), TypeName::List)
                | (Value::Form(_), TypeName::Form)
        )
    }

    /// Borrow the inner text if this is a [`Value::String`].
    #[must_use]
    pub fn as_str(&self) -> Option<&str> {
        match self {
            Value::String(s) => Some(s),
            _ => None,
        }
    }

    /// The inner number if this is a [`Value::Number`].
    #[must_use]
    pub const fn as_number(&self) -> Option<f64> {
        match self {
            Value::Number(n) => Some(*n),
            _ => None,
        }
    }

    /// The inner boolean if this is a [`Value::Bool`].
    #[must_use]
    pub const fn as_bool(&self) -> Option<bool> {
        match self {
            Value::Bool(b) => Some(*b),
            _ => None,
        }
    }

    /// Borrow the inner elements if this is a [`Value::List`].
    #[must_use]
    pub fn as_list(&self) -> Option<&[Value]> {
        match self {
            Value::List(items) => Some(items),
            _ => None,
        }
    }

    /// Render this value to its canonical string form using `sep` to join list
    /// elements (SPEC deterministic `→ string`: numbers/bools/lists stringify
    /// deterministically; lists join with `_sep`).
    ///
    /// - `String(s)` → `s`
    /// - `Number(n)` → integral values without a fractional part (`2`, not
    ///   `2.0`); non-integral values in shortest round-tripping form (`1.5`)
    /// - `Bool(b)` → `"true"` / `"false"`
    /// - `List(items)` → each element rendered and joined with `sep`
    #[must_use]
    pub fn render(&self, sep: &str) -> String {
        match self {
            Value::String(s) => s.clone(),
            Value::Number(n) => format_number(*n),
            Value::Bool(b) => (if *b { "true" } else { "false" }).to_owned(),
            Value::List(items) => items
                .iter()
                .map(|item| item.render(sep))
                .collect::<Vec<_>>()
                .join(sep),
            // A form renders WITH braces so bare output/Display reads as a form
            // and round-trips against `Expr::Quote` (`{(2 + 3)}`). Operand
            // coercion uses the INNER source instead (see `coerce_deterministic`).
            Value::Form(inner) => format!("{{{}}}", inner.render()),
        }
    }

    /// Attempt a *deterministic* coercion of this value to `target`, using `sep`
    /// to join list elements when rendering to a string (SPEC §Types & coercion,
    /// steps 1–2 — before any LLM call).
    ///
    /// Returns `Some(value)` when a deterministic rule applies; returns `None`
    /// when no deterministic rule produces `target`, so the caller can fall back
    /// to the constrained LLM coercion (bd-ecb930) or raise a loud error
    /// (bd-20df97). Note `list → number` has no deterministic rule here and no
    /// LLM path either — it is always an error, enforced by the loud-error layer.
    ///
    /// Deterministic rules:
    /// - `→ string`: always succeeds — any value stringifies deterministically
    ///   (numbers/bools render; lists join with `sep`).
    /// - `→ number`: a number stays; a numeric string parses (`"1"` → `1`);
    ///   any other source has no deterministic rule.
    /// - `→ bool`: a bool stays; the trimmed strings `"true"` / `"false"` map to
    ///   `true` / `false`; any other source has no deterministic rule.
    /// - `→ list`: a list stays; scalars have no deterministic rule.
    #[must_use]
    pub fn coerce_deterministic(&self, target: TypeName, sep: &str) -> Option<Value> {
        // Step 1: a value already of the requested type is used as-is.
        if self.is_type(target) {
            return Some(self.clone());
        }
        // op×Form: a form in a NON-form slot coerces via its INNER source (no
        // braces), so a non-application operator operates on the source text
        // (`@{a+b}` → "a + b", `{2+3}` in a numeric slot → "2 + 3" → parse). The
        // callable-form path is the application operator only.
        if let Value::Form(inner) = self {
            return Value::String(inner.render()).coerce_deterministic(target, sep);
        }
        // Step 2: deterministic parses/renders. Anything not handled here is
        // `None` (defer to the LLM fallback / loud-error layers).
        match target {
            // Every value has a deterministic string form.
            TypeName::String => Some(Value::String(self.render(sep))),
            TypeName::Number => match self {
                Value::String(s) => parse_number_str(s).map(Value::Number),
                // A bool counts as 1/0, so `$fold%({$0+$1}, [bool…])` sums the
                // trues — the correctness-gate count idiom over a bool predicate.
                Value::Bool(b) => Some(Value::Number(if *b { 1.0 } else { 0.0 })),
                _ => None,
            },
            TypeName::Bool => match self {
                Value::String(s) => match s.trim() {
                    "true" => Some(Value::Bool(true)),
                    "false" => Some(Value::Bool(false)),
                    _ => None,
                },
                _ => None,
            },
            // No deterministic scalar → list rule (already-list handled above).
            TypeName::List => None,
            // No deterministic rule turns a non-form value INTO a form (quoting is
            // syntactic: `{…}`). A form in a non-form slot is handled above via its
            // inner source, so this arm is only reached for non-form self → form.
            TypeName::Form => None,
        }
    }

    /// Coerce this value to `target`, using `sep` to join list elements when
    /// rendering to a string, raising a **loud error** when the target type
    /// cannot be produced (SPEC §Types & coercion: "Coercion that cannot produce
    /// the target type is a loud error").
    ///
    /// This is the deterministic-or-error coercion, correct for `det` mode and
    /// for the hard rules that hold in every mode:
    /// - `list → number` is **always** an error — it is structurally impossible
    ///   and the LLM path is never attempted for it.
    /// - otherwise the deterministic rules ([`Value::coerce_deterministic`]) are
    ///   tried, and a value that no deterministic rule can convert is a loud
    ///   [`CoerceError`].
    ///
    /// The constrained LLM coercion fallback (bd-ecb930) slots in between the
    /// deterministic attempt and the loud error in `llm` mode; it turns vague
    /// text (e.g. `"ten to twenty"`) into a typed value. Until it lands, this
    /// function is the terminal coercion entry point.
    ///
    /// # Errors
    /// Returns [`CoerceError`] when the value cannot be represented as `target`.
    pub fn coerce(&self, target: TypeName, sep: &str) -> Result<Value, CoerceError> {
        // op×Form: a form coerces via its inner source in any non-form slot, so the
        // source string carries through BOTH the deterministic and (future) LLM
        // coercion — `{2+3}` → number tries "2 + 3", never the braced form.
        if let Value::Form(inner) = self {
            if target == TypeName::Form {
                return Ok(self.clone());
            }
            return Value::String(inner.render()).coerce(target, sep);
        }
        // `list → number` is structurally impossible: a loud error in every
        // mode, and never routed to the LLM fallback.
        if matches!((self, target), (Value::List(_), TypeName::Number)) {
            return Err(CoerceError::list_to_number(self, sep));
        }
        // Deterministic parses/renders first (SPEC steps 1–2).
        if let Some(value) = self.coerce_deterministic(target, sep) {
            return Ok(value);
        }
        // NB: the LLM coercion fallback (bd-ecb930) is attempted here, before the
        // loud error, once an LLM backend is available.
        Err(CoerceError::unrepresentable(self, target, sep))
    }
}

/// Render an nlir number to its canonical string form.
///
/// Integral values within the exactly-representable `f64` integer range render
/// without a fractional part (`2`, not `2.0`); everything else uses the standard
/// shortest round-tripping representation. `-0.0` normalises to `"0"`.
#[must_use]
pub fn format_number(n: f64) -> String {
    // Largest magnitude with exact integer representation in an f64 (2^53).
    const MAX_EXACT_INT: f64 = 9_007_199_254_740_992.0;

    if n == 0.0 {
        // Covers both 0.0 and -0.0 without a stray "-0".
        return "0".to_owned();
    }
    if n.is_finite() && n.fract() == 0.0 && n.abs() <= MAX_EXACT_INT {
        // Safe: finite, integral, and within the exact-integer range.
        #[allow(clippy::cast_possible_truncation)]
        return (n as i64).to_string();
    }
    // Non-integral, or beyond exact-integer precision, or non-finite
    // (NaN / inf): defer to the standard shortest representation.
    format!("{n}")
}

/// Parse a string into a number using only **deterministic**, offline rules —
/// the number forms nlir coerces without a model round-trip. Tries, in order:
/// a plain float (`"42"`, `"3.5"`, `"-5"`, `"1e3"`, `"+3"`); a currency amount
/// (`"$0.25"`, `"$1,000"`); a hex (`"0xFF"`) or binary (`"0b101"`) integer
/// literal (optional sign); a comma-grouped integer (`"1,000"`); a percentage
/// (`"50%"` → `0.5`); and a simple fraction (`"1/2"` → `0.5`). Returns `None` for
/// anything else, so richer text (spelled numbers, ranges, …) still defers to the
/// LLM coercion / loud-error layer.
#[must_use]
#[allow(clippy::cast_precision_loss)]
fn parse_number_str(raw: &str) -> Option<f64> {
    let s = raw.trim();
    if s.is_empty() {
        return None;
    }
    // Plain float: ints, decimals, signs, scientific notation.
    if let Ok(n) = s.parse::<f64>() {
        return Some(n);
    }
    // Currency: "$1", "$0.25", "$1,000" -> strip the leading currency mark and
    // re-parse the amount (so its decimals / thousands separators are handled).
    if let Some(rest) = s.strip_prefix('$') {
        return parse_number_str(rest);
    }
    // Hex / binary integer literals, with an optional leading sign.
    let (sign, body) = if let Some(rest) = s.strip_prefix('-') {
        (-1.0_f64, rest)
    } else {
        (1.0_f64, s.strip_prefix('+').unwrap_or(s))
    };
    if let Some(hex) = body.strip_prefix("0x").or_else(|| body.strip_prefix("0X")) {
        if let Ok(n) = i64::from_str_radix(hex, 16) {
            return Some(sign * n as f64);
        }
    }
    if let Some(bin) = body.strip_prefix("0b").or_else(|| body.strip_prefix("0B")) {
        if let Ok(n) = i64::from_str_radix(bin, 2) {
            return Some(sign * n as f64);
        }
    }
    // Comma-grouped thousands: "1,000" -> 1000.
    if s.contains(',') {
        if let Ok(n) = s.replace(',', "").parse::<f64>() {
            return Some(n);
        }
    }
    // Percentage: "50%" -> 0.5.
    if let Some(pct) = s.strip_suffix('%') {
        if let Ok(n) = pct.trim().parse::<f64>() {
            return Some(n / 100.0);
        }
    }
    // Simple fraction: "1/2" -> 0.5 (guards divide-by-zero).
    if let Some((num, den)) = s.split_once('/') {
        if let (Ok(a), Ok(b)) = (num.trim().parse::<f64>(), den.trim().parse::<f64>()) {
            if b != 0.0 {
                return Some(a / b);
            }
        }
    }
    None
}

/// Maximum length of the source-value snippet embedded in a [`CoerceError`]
/// message, so a huge operand cannot produce an unbounded error string.
const COERCE_ERROR_SOURCE_MAX: usize = 80;

/// Why a [`Value::coerce`] failed (SPEC §Types & coercion loud errors).
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum CoerceErrorKind {
    /// `list → number` — structurally impossible; always an error and never
    /// routed to the LLM coercion path.
    ListToNumber,
    /// No deterministic rule produced the target type and (in `llm` mode) the
    /// LLM coercion fallback did not yield a value either.
    Unrepresentable,
}

/// A loud coercion failure: a value could not be produced as the required type.
#[derive(Debug, Clone, PartialEq)]
pub struct CoerceError {
    /// The source value's type.
    pub from: TypeName,
    /// The requested target type.
    pub to: TypeName,
    /// Which loud-error rule fired.
    pub kind: CoerceErrorKind,
    /// A bounded rendering of the offending source value, for the message.
    pub source: String,
}

impl CoerceError {
    /// The always-invalid `list → number` coercion.
    #[must_use]
    pub fn list_to_number(value: &Value, sep: &str) -> Self {
        Self {
            from: value.type_name(),
            to: TypeName::Number,
            kind: CoerceErrorKind::ListToNumber,
            source: bounded_source(value, sep),
        }
    }

    /// A value that no deterministic (or LLM) rule could convert to `target`.
    #[must_use]
    pub fn unrepresentable(value: &Value, target: TypeName, sep: &str) -> Self {
        Self {
            from: value.type_name(),
            to: target,
            kind: CoerceErrorKind::Unrepresentable,
            source: bounded_source(value, sep),
        }
    }
}

/// Render a value for an error message, truncated to [`COERCE_ERROR_SOURCE_MAX`]
/// characters (on a char boundary) with an ellipsis when longer.
fn bounded_source(value: &Value, sep: &str) -> String {
    let rendered = value.render(sep);
    match rendered.char_indices().nth(COERCE_ERROR_SOURCE_MAX) {
        None => rendered,
        Some((cut, _)) => format!("{}…", &rendered[..cut]),
    }
}

impl fmt::Display for CoerceError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self.kind {
            CoerceErrorKind::ListToNumber => write!(
                f,
                "cannot coerce {from} `{src}` to number: a list is never a number",
                from = self.from,
                src = self.source,
            ),
            CoerceErrorKind::Unrepresentable => write!(
                f,
                "cannot coerce {from} `{src}` to {to}: no deterministic or model coercion produced a {to}",
                from = self.from,
                src = self.source,
                to = self.to,
            ),
        }
    }
}

impl std::error::Error for CoerceError {}

impl fmt::Display for Value {
    /// Renders with the [`DEFAULT_SEP`] separator. Evaluation code that has the
    /// live `_sep` should call [`Value::render`] with it instead.
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str(&self.render(DEFAULT_SEP))
    }
}

impl From<String> for Value {
    fn from(value: String) -> Self {
        Value::String(value)
    }
}

impl From<&str> for Value {
    fn from(value: &str) -> Self {
        Value::String(value.to_owned())
    }
}

impl From<f64> for Value {
    fn from(value: f64) -> Self {
        Value::Number(value)
    }
}

impl From<bool> for Value {
    fn from(value: bool) -> Self {
        Value::Bool(value)
    }
}

impl From<Vec<Value>> for Value {
    fn from(value: Vec<Value>) -> Self {
        Value::List(value)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn type_name_maps_each_variant() {
        assert_eq!(Value::string("x").type_name(), TypeName::String);
        assert_eq!(Value::number(1.0).type_name(), TypeName::Number);
        assert_eq!(Value::bool(true).type_name(), TypeName::Bool);
        assert_eq!(Value::list(vec![]).type_name(), TypeName::List);
    }

    #[test]
    fn is_type_matches_only_own_tag() {
        let v = Value::number(3.0);
        assert!(v.is_type(TypeName::Number));
        assert!(!v.is_type(TypeName::String));
        assert!(!v.is_type(TypeName::Bool));
        assert!(!v.is_type(TypeName::List));
    }

    #[test]
    fn accessors_return_inner_only_for_matching_variant() {
        assert_eq!(Value::string("hi").as_str(), Some("hi"));
        assert_eq!(Value::number(2.5).as_str(), None);

        assert_eq!(Value::number(2.5).as_number(), Some(2.5));
        assert_eq!(Value::string("2.5").as_number(), None);

        assert_eq!(Value::bool(false).as_bool(), Some(false));
        assert_eq!(Value::number(0.0).as_bool(), None);

        let list = Value::list(vec![Value::number(1.0), Value::number(2.0)]);
        assert_eq!(list.as_list().map(<[Value]>::len), Some(2));
        assert!(Value::string("x").as_list().is_none());
    }

    #[test]
    fn render_string_is_identity() {
        assert_eq!(Value::string("one two").render(DEFAULT_SEP), "one two");
    }

    #[test]
    fn render_bool_is_lowercase_word() {
        assert_eq!(Value::bool(true).render(DEFAULT_SEP), "true");
        assert_eq!(Value::bool(false).render(DEFAULT_SEP), "false");
    }

    #[test]
    fn integral_numbers_render_without_fraction() {
        // SPEC: `1+1` → "2" (number, stringified on output).
        assert_eq!(Value::number(2.0).render(DEFAULT_SEP), "2");
        assert_eq!(Value::number(0.0).render(DEFAULT_SEP), "0");
        assert_eq!(Value::number(-0.0).render(DEFAULT_SEP), "0");
        assert_eq!(Value::number(-7.0).render(DEFAULT_SEP), "-7");
        assert_eq!(Value::number(1000.0).render(DEFAULT_SEP), "1000");
    }

    #[test]
    fn non_integral_numbers_render_shortest() {
        assert_eq!(Value::number(1.5).render(DEFAULT_SEP), "1.5");
        assert_eq!(Value::number(-0.25).render(DEFAULT_SEP), "-0.25");
    }

    #[test]
    fn non_finite_numbers_defer_to_std_formatting() {
        assert_eq!(format_number(f64::INFINITY), "inf");
        assert_eq!(format_number(f64::NEG_INFINITY), "-inf");
        assert_eq!(format_number(f64::NAN), "NaN");
    }

    #[test]
    fn list_joins_elements_with_separator() {
        let list = Value::list(vec![
            Value::string("a"),
            Value::string("b"),
            Value::string("c"),
        ]);
        assert_eq!(list.render(", "), "a, b, c");
        // `_sep=\ ;[a,b]` → "a b" (SPEC example, space separator).
        assert_eq!(
            Value::list(vec![Value::string("a"), Value::string("b")]).render(" "),
            "a b"
        );
    }

    #[test]
    fn list_render_is_recursive_and_type_mixed() {
        let list = Value::list(vec![
            Value::number(1.0),
            Value::bool(true),
            Value::list(vec![Value::string("x"), Value::string("y")]),
        ]);
        // Nested list uses the same separator.
        assert_eq!(list.render("|"), "1|true|x|y");
    }

    #[test]
    fn display_uses_default_separator() {
        let list = Value::list(vec![Value::string("a"), Value::string("b")]);
        assert_eq!(list.to_string(), format!("a{DEFAULT_SEP}b"));
        assert_eq!(Value::number(42.0).to_string(), "42");
    }

    #[test]
    fn from_impls_build_expected_variants() {
        assert_eq!(Value::from("s"), Value::String("s".to_owned()));
        assert_eq!(Value::from("s".to_owned()), Value::String("s".to_owned()));
        assert_eq!(Value::from(3.0), Value::Number(3.0));
        assert_eq!(Value::from(true), Value::Bool(true));
        assert_eq!(
            Value::from(vec![Value::number(1.0)]),
            Value::List(vec![Value::Number(1.0)])
        );
    }

    // --- deterministic coercion (bd-456f12) ---

    #[test]
    fn coerce_same_type_is_identity() {
        assert_eq!(
            Value::number(3.0).coerce_deterministic(TypeName::Number, "\n"),
            Some(Value::number(3.0))
        );
        let list = Value::list(vec![Value::string("a")]);
        assert_eq!(
            list.coerce_deterministic(TypeName::List, "\n"),
            Some(list.clone())
        );
    }

    #[test]
    fn coerce_to_string_always_succeeds_deterministically() {
        // number/bool/list all stringify without an LLM call.
        assert_eq!(
            Value::number(2.0).coerce_deterministic(TypeName::String, "\n"),
            Some(Value::string("2"))
        );
        assert_eq!(
            Value::bool(true).coerce_deterministic(TypeName::String, "\n"),
            Some(Value::string("true"))
        );
        let list = Value::list(vec![Value::string("a"), Value::string("b")]);
        assert_eq!(
            list.coerce_deterministic(TypeName::String, ", "),
            Some(Value::string("a, b"))
        );
    }

    #[test]
    fn coerce_string_to_number_parses_numeric_text() {
        assert_eq!(
            Value::string("1").coerce_deterministic(TypeName::Number, "\n"),
            Some(Value::number(1.0))
        );
        assert_eq!(
            Value::string("1.5").coerce_deterministic(TypeName::Number, "\n"),
            Some(Value::number(1.5))
        );
        assert_eq!(
            Value::string("-2").coerce_deterministic(TypeName::Number, "\n"),
            Some(Value::number(-2.0))
        );
        // Surrounding whitespace is tolerated.
        assert_eq!(
            Value::string("  3  ").coerce_deterministic(TypeName::Number, "\n"),
            Some(Value::number(3.0))
        );
        // Non-numeric text has no deterministic rule (defers to LLM/error layer).
        assert_eq!(
            Value::string("ten").coerce_deterministic(TypeName::Number, "\n"),
            None
        );
        // A bool counts as 1/0 (the correctness-gate sum idiom).
        assert_eq!(
            Value::bool(true).coerce_deterministic(TypeName::Number, "\n"),
            Some(Value::number(1.0))
        );
        assert_eq!(
            Value::bool(false).coerce_deterministic(TypeName::Number, "\n"),
            Some(Value::number(0.0))
        );
    }

    #[test]
    fn coerce_string_to_number_handles_offline_special_forms() {
        // Hex, binary, comma-grouped, percent, and simple-fraction literals all
        // coerce deterministically (no LLM round-trip) alongside plain floats.
        let cases = [
            ("0xFF", 255.0),
            ("0X10", 16.0),
            ("0b101", 5.0),
            ("-0x10", -16.0),
            ("1,000", 1000.0),
            ("1,234,567", 1_234_567.0),
            ("50%", 0.5),
            ("5%", 0.05),
            ("1/2", 0.5),
            ("3/4", 0.75),
            // Currency amounts (strip the mark, decimals / thousands handled).
            ("$1", 1.0),
            ("$0.25", 0.25),
            ("$1,000", 1000.0),
            // Plain forms are unaffected.
            ("42", 42.0),
            ("1e3", 1000.0),
            ("+3", 3.0),
        ];
        for (input, expected) in cases {
            assert_eq!(
                Value::string(input).coerce_deterministic(TypeName::Number, "\n"),
                Some(Value::number(expected)),
                "deterministic coercion of {input:?}",
            );
        }
        // Divide-by-zero fraction and non-numeric text still defer (None).
        assert_eq!(
            Value::string("1/0").coerce_deterministic(TypeName::Number, "\n"),
            None
        );
        assert_eq!(
            Value::string("a murder of crows").coerce_deterministic(TypeName::Number, "\n"),
            None
        );
    }

    #[test]
    fn coerce_string_to_bool_maps_true_false_only() {
        assert_eq!(
            Value::string("true").coerce_deterministic(TypeName::Bool, "\n"),
            Some(Value::bool(true))
        );
        assert_eq!(
            Value::string(" false ").coerce_deterministic(TypeName::Bool, "\n"),
            Some(Value::bool(false))
        );
        // "yes"/"1" are not deterministic bools (an LLM may interpret them).
        assert_eq!(
            Value::string("yes").coerce_deterministic(TypeName::Bool, "\n"),
            None
        );
    }

    #[test]
    fn coerce_without_deterministic_rule_returns_none() {
        // list -> number: never deterministic (and an error in the loud layer).
        assert_eq!(
            Value::list(vec![Value::number(1.0)]).coerce_deterministic(TypeName::Number, "\n"),
            None
        );
        // number -> bool: no deterministic rule. (bool -> number DOES coerce to
        // 1/0 now — see coerce_string_to_number_parses_numeric_text.)
        assert_eq!(
            Value::number(1.0).coerce_deterministic(TypeName::Bool, "\n"),
            None
        );
        // scalar -> list: no deterministic rule.
        assert_eq!(
            Value::string("a").coerce_deterministic(TypeName::List, "\n"),
            None
        );
    }

    // --- loud coercion errors + list->number (bd-20df97) ---

    #[test]
    fn coerce_succeeds_where_deterministic_rule_applies() {
        assert_eq!(
            Value::number(2.0).coerce(TypeName::String, "\n"),
            Ok(Value::string("2"))
        );
        assert_eq!(
            Value::string("1").coerce(TypeName::Number, "\n"),
            Ok(Value::number(1.0))
        );
        // -> string never errors, even for a list.
        let list = Value::list(vec![Value::string("a"), Value::string("b")]);
        assert_eq!(
            list.coerce(TypeName::String, ", "),
            Ok(Value::string("a, b"))
        );
    }

    #[test]
    fn coerce_list_to_number_is_always_a_loud_error() {
        let list = Value::list(vec![Value::number(1.0), Value::number(2.0)]);
        let err = list
            .coerce(TypeName::Number, ", ")
            .expect_err("list -> number errors");
        assert_eq!(err.kind, CoerceErrorKind::ListToNumber);
        assert_eq!(err.from, TypeName::List);
        assert_eq!(err.to, TypeName::Number);
        let msg = err.to_string();
        assert!(msg.contains("list"), "message names the source type: {msg}");
        assert!(
            msg.contains("number"),
            "message names the target type: {msg}"
        );
    }

    #[test]
    fn coerce_unrepresentable_is_a_loud_error() {
        // Non-numeric text with no deterministic rule and (for now) no LLM path.
        let err = Value::string("ten")
            .coerce(TypeName::Number, "\n")
            .expect_err("non-numeric string -> number errors");
        assert_eq!(err.kind, CoerceErrorKind::Unrepresentable);
        assert_eq!(err.from, TypeName::String);
        assert_eq!(err.to, TypeName::Number);
        // A non-true/false string -> bool is likewise unrepresentable here.
        assert_eq!(
            Value::string("yes")
                .coerce(TypeName::Bool, "\n")
                .expect_err("non-bool string -> bool errors")
                .kind,
            CoerceErrorKind::Unrepresentable
        );
    }

    #[test]
    fn coerce_error_source_snippet_is_bounded() {
        let long = "x".repeat(500);
        let err = Value::string(long)
            .coerce(TypeName::Number, "\n")
            .expect_err("long non-numeric string -> number errors");
        // Truncated to the bound + a single-char ellipsis marker.
        assert!(err.source.chars().count() <= COERCE_ERROR_SOURCE_MAX + 1);
        assert!(err.source.ends_with('…'));
    }

    #[test]
    fn form_value_renders_braced_and_coerces_via_inner_source() {
        use crate::parser::Expr;
        // A quoted form (`{…}`) carries an unevaluated Expr as first-class data.
        let form = Value::form(Expr::Number(5.0));
        assert_eq!(form.type_name(), TypeName::Form);
        assert!(form.is_type(TypeName::Form));
        // Output / Display render WITH braces, so it round-trips against Expr::Quote.
        assert_eq!(form.render(DEFAULT_SEP), "{5}");
        assert_eq!(form.to_string(), "{5}");
        // op×Form: a form in a non-form slot coerces to its INNER source (no braces),
        // so a non-application operator operates on the source text.
        assert_eq!(
            form.coerce(TypeName::String, DEFAULT_SEP).unwrap(),
            Value::String("5".to_owned())
        );
        // The inner source flows through to numeric coercion ("5" parses to 5).
        assert_eq!(
            form.coerce(TypeName::Number, DEFAULT_SEP).unwrap(),
            Value::Number(5.0)
        );
        // A form stays a form for a form slot (the application-operand path).
        assert_eq!(
            form.coerce(TypeName::Form, DEFAULT_SEP).unwrap(),
            form.clone()
        );
    }
}
