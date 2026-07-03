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

    /// The [`TypeName`] of this value — the shared type tag used by operator
    /// `operands:` / `result:` declarations and the coercion layer.
    #[must_use]
    pub const fn type_name(&self) -> TypeName {
        match self {
            Value::String(_) => TypeName::String,
            Value::Number(_) => TypeName::Number,
            Value::Bool(_) => TypeName::Bool,
            Value::List(_) => TypeName::List,
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
        // Step 2: deterministic parses/renders. Anything not handled here is
        // `None` (defer to the LLM fallback / loud-error layers).
        match target {
            // Every value has a deterministic string form.
            TypeName::String => Some(Value::String(self.render(sep))),
            TypeName::Number => match self {
                Value::String(s) => s.trim().parse::<f64>().ok().map(Value::Number),
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
        }
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
        // number -> bool and bool -> number: no deterministic rule.
        assert_eq!(
            Value::number(1.0).coerce_deterministic(TypeName::Bool, "\n"),
            None
        );
        assert_eq!(
            Value::bool(true).coerce_deterministic(TypeName::Number, "\n"),
            None
        );
        // scalar -> list: no deterministic rule.
        assert_eq!(
            Value::string("a").coerce_deterministic(TypeName::List, "\n"),
            None
        );
    }
}
