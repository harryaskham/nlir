//! nlir deterministic operator realisation (SPEC §Modes).
//!
//! An operator is realised either deterministically (no network) or via an LLM.
//! This module holds the **deterministic** string/number realisations the
//! evaluator (bd-2b226d) calls after it has resolved and coerced an operator's
//! operands:
//!
//! - [`reduce`] — numeric reduction (`+ - * / **`) plus string ops (`++` concat,
//!   `//` split), SPEC `reduce:` (bd-fa5ee2, bd-c833a8).
//! - [`template`] — template substitution (`%`, `%N`, `%%`), SPEC `template:`
//!   (bd-1779cd).
//! - [`join`] — variadic join with the configured separator, SPEC `join:`
//!   (bd-710166).
//!
//! All three are pure functions over already-coerced [`Value`] operands; the
//! `command:` and LLM realisations are separate beads. Operands render through
//! [`Value::render`] using the active `_sep` for list values.

use std::fmt;

use crate::config::ReduceOp;
use crate::value::Value;

/// A deterministic-realisation error. Currently only the numeric [`reduce`]
/// path is fallible (template/join are total); the `command:` / LLM realisation
/// beads extend this as they land.
#[derive(Debug, Clone, PartialEq)]
pub enum RealiseError {
    /// A numeric reduction got the wrong number of operands (`- / **` are
    /// binary; `+ *` need at least one).
    Arity {
        op: ReduceOp,
        expected: &'static str,
        got: usize,
    },
    /// A reduction operand was not a number (the eval layer should coerce first;
    /// this guards the realisation boundary). `position` is 0-based.
    NotNumber { op: ReduceOp, position: usize },
    /// Division by zero in a `/` reduction.
    DivByZero,
}

impl fmt::Display for RealiseError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            RealiseError::Arity { op, expected, got } => {
                write!(f, "reduce {op:?} expects {expected} operand(s), got {got}")
            }
            RealiseError::NotNumber { op, position } => {
                write!(f, "reduce {op:?} operand {position} is not a number")
            }
            RealiseError::DivByZero => write!(f, "division by zero"),
        }
    }
}

impl std::error::Error for RealiseError {}

/// Deterministic numeric reduction (SPEC operators `+ - * / **`, `reduce:`).
///
/// Operands must already be coerced to numbers by the eval layer. `+`/`*` fold
/// over all operands (variadic, ≥1); `-`/`/`/`**` are binary. `/` by zero is a
/// loud error.
pub fn reduce(op: ReduceOp, operands: &[Value]) -> Result<Value, RealiseError> {
    // String realisations branch before numeric coercion, since `numbers()`
    // errors on non-numeric operands (bd-c833a8).
    match op {
        ReduceOp::Concat => return Ok(concat(operands)),
        ReduceOp::Split => return split(op, operands),
        ReduceOp::Eq => return compare_eq(op, operands, false),
        ReduceOp::Ne => return compare_eq(op, operands, true),
        _ => {}
    }
    let nums = numbers(op, operands)?;
    // Numeric comparisons need the coerced numbers but yield a bool, not a number.
    match op {
        ReduceOp::Le => {
            let (a, b) = binary(op, &nums)?;
            return Ok(Value::bool(a <= b));
        }
        ReduceOp::Ge => {
            let (a, b) = binary(op, &nums)?;
            return Ok(Value::bool(a >= b));
        }
        _ => {}
    }
    let result = match op {
        ReduceOp::Add => {
            require_min(op, &nums, 1)?;
            nums.iter().sum::<f64>()
        }
        ReduceOp::Mul => {
            require_min(op, &nums, 1)?;
            nums.iter().product::<f64>()
        }
        ReduceOp::Sub => {
            let (a, b) = binary(op, &nums)?;
            a - b
        }
        ReduceOp::Div => {
            let (a, b) = binary(op, &nums)?;
            if b == 0.0 {
                return Err(RealiseError::DivByZero);
            }
            a / b
        }
        ReduceOp::Pow => {
            let (a, b) = binary(op, &nums)?;
            a.powf(b)
        }
        ReduceOp::Concat
        | ReduceOp::Split
        | ReduceOp::Eq
        | ReduceOp::Ne
        | ReduceOp::Le
        | ReduceOp::Ge => unreachable!("string/comparison ops handled above"),
    };
    Ok(Value::number(result))
}

/// Value equality for `==` / `!=` (binary): compares the two operands by their
/// canonical render, so numbers, strings, and bools all compare by text
/// (`5 == 5.0` is true since both render "5"). `negate` yields `!=`.
fn compare_eq(op: ReduceOp, operands: &[Value], negate: bool) -> Result<Value, RealiseError> {
    if operands.len() != 2 {
        return Err(RealiseError::Arity {
            op,
            expected: "exactly 2",
            got: operands.len(),
        });
    }
    let eq = operand_str(&operands[0]) == operand_str(&operands[1]);
    Ok(Value::bool(eq ^ negate))
}

/// Concatenate the string renders of every operand (`++`, variadic). The eval
/// layer coerces operands to String, so `as_str` succeeds; the defensive
/// fallback renders anything else with a space separator. Empty operand set
/// yields the empty string.
fn concat(operands: &[Value]) -> Value {
    let joined: String = operands.iter().map(operand_str).collect();
    Value::string(joined)
}

/// Split the first operand by the second into a list of strings (`//`, binary).
/// An empty separator splits into characters.
fn split(op: ReduceOp, operands: &[Value]) -> Result<Value, RealiseError> {
    if operands.len() != 2 {
        return Err(RealiseError::Arity {
            op,
            expected: "exactly 2",
            got: operands.len(),
        });
    }
    let text = operand_str(&operands[0]);
    let sep = operand_str(&operands[1]);
    let parts: Vec<Value> = if sep.is_empty() {
        text.chars().map(|c| Value::string(c.to_string())).collect()
    } else {
        text.split(sep.as_str()).map(Value::string).collect()
    };
    Ok(Value::List(parts))
}

/// Render an operand as an owned string for the string ops: the direct string
/// when it is one, else its rendered form (space-separated for lists).
fn operand_str(value: &Value) -> String {
    value
        .as_str()
        .map(str::to_owned)
        .unwrap_or_else(|| value.render(" "))
}

/// Extract every operand as a number, erroring on the first non-number.
fn numbers(op: ReduceOp, operands: &[Value]) -> Result<Vec<f64>, RealiseError> {
    operands
        .iter()
        .enumerate()
        .map(|(position, value)| {
            value
                .as_number()
                .ok_or(RealiseError::NotNumber { op, position })
        })
        .collect()
}

/// Require at least `min` operands for a variadic reduction.
fn require_min(op: ReduceOp, nums: &[f64], min: usize) -> Result<(), RealiseError> {
    if nums.len() < min {
        Err(RealiseError::Arity {
            op,
            expected: "at least 1",
            got: nums.len(),
        })
    } else {
        Ok(())
    }
}

/// Require exactly two operands for a binary reduction.
fn binary(op: ReduceOp, nums: &[f64]) -> Result<(f64, f64), RealiseError> {
    match nums {
        [a, b] => Ok((*a, *b)),
        _ => Err(RealiseError::Arity {
            op,
            expected: "2",
            got: nums.len(),
        }),
    }
}

/// Deterministic template realisation (SPEC §Modes `template:`).
///
/// Substitutes operands into `tmpl`:
/// - `%%` → a literal `%`;
/// - `%N` (one or more digits) → operand `N` (0-based), rendered;
/// - a bare `%` (the arity-1 form, e.g. `"not %"`) → operand `0`, rendered.
///
/// Operands render through [`Value::render`] with `sep` (list join). An
/// out-of-range `%N` (or a bare `%` with no operands) contributes nothing.
#[must_use]
pub fn template(tmpl: &str, operands: &[Value], sep: &str) -> Value {
    let mut out = String::with_capacity(tmpl.len());
    let mut chars = tmpl.chars().peekable();
    while let Some(c) = chars.next() {
        if c != '%' {
            out.push(c);
            continue;
        }
        match chars.peek().copied() {
            // `%%` — a literal percent.
            Some('%') => {
                chars.next();
                out.push('%');
            }
            // `%N` — operand by index.
            Some(digit) if digit.is_ascii_digit() => {
                let mut index = String::new();
                while let Some(&d) = chars.peek() {
                    if d.is_ascii_digit() {
                        index.push(d);
                        chars.next();
                    } else {
                        break;
                    }
                }
                if let Some(value) = index.parse::<usize>().ok().and_then(|i| operands.get(i)) {
                    out.push_str(&value.render(sep));
                }
            }
            // bare `%` — the single (arity-1) operand.
            _ => {
                if let Some(value) = operands.first() {
                    out.push_str(&value.render(sep));
                }
            }
        }
    }
    Value::string(out)
}

/// Deterministic variadic join realisation (SPEC §Modes `join:`).
///
/// Renders each operand (with `sep` for list values) and joins them with
/// `separator` — the operator's configured `join:` string, e.g. `" and "` so
/// `a&b&c` → `"a and b and c"`.
#[must_use]
pub fn join(operands: &[Value], separator: &str, sep: &str) -> Value {
    let rendered: Vec<String> = operands.iter().map(|value| value.render(sep)).collect();
    Value::string(rendered.join(separator))
}

#[cfg(test)]
mod tests {
    use super::*;

    fn nums(values: &[f64]) -> Vec<Value> {
        values.iter().map(|n| Value::number(*n)).collect()
    }

    // -- reduce (bd-fa5ee2) ------------------------------------------------

    #[test]
    fn reduce_add_and_mul_fold_all_operands() {
        assert_eq!(
            reduce(ReduceOp::Add, &nums(&[1.0, 2.0, 3.0])),
            Ok(Value::number(6.0))
        );
        assert_eq!(
            reduce(ReduceOp::Mul, &nums(&[2.0, 3.0, 4.0])),
            Ok(Value::number(24.0))
        );
        // Single operand folds to itself.
        assert_eq!(reduce(ReduceOp::Add, &nums(&[5.0])), Ok(Value::number(5.0)));
        // No operands is an arity error.
        assert!(matches!(
            reduce(ReduceOp::Add, &[]),
            Err(RealiseError::Arity { .. })
        ));
    }

    #[test]
    fn reduce_binary_ops() {
        assert_eq!(
            reduce(ReduceOp::Sub, &nums(&[5.0, 3.0])),
            Ok(Value::number(2.0))
        );
        assert_eq!(
            reduce(ReduceOp::Div, &nums(&[10.0, 2.0])),
            Ok(Value::number(5.0))
        );
        assert_eq!(
            reduce(ReduceOp::Pow, &nums(&[2.0, 3.0])),
            Ok(Value::number(8.0))
        );
        // Matches SPEC num-index: (1+1)**3 = 8.
        assert_eq!(
            reduce(ReduceOp::Pow, &nums(&[2.0, 3.0])),
            Ok(Value::number(8.0))
        );
    }

    #[test]
    fn reduce_div_by_zero_is_loud() {
        assert_eq!(
            reduce(ReduceOp::Div, &nums(&[1.0, 0.0])),
            Err(RealiseError::DivByZero)
        );
    }

    #[test]
    fn reduce_binary_wrong_arity_errors() {
        assert!(matches!(
            reduce(ReduceOp::Sub, &nums(&[1.0, 2.0, 3.0])),
            Err(RealiseError::Arity { got: 3, .. })
        ));
        assert!(matches!(
            reduce(ReduceOp::Pow, &nums(&[2.0])),
            Err(RealiseError::Arity { got: 1, .. })
        ));
    }

    #[test]
    fn reduce_rejects_non_number_operand() {
        let operands = vec![Value::number(1.0), Value::string("two")];
        assert_eq!(
            reduce(ReduceOp::Add, &operands),
            Err(RealiseError::NotNumber {
                op: ReduceOp::Add,
                position: 1
            })
        );
    }

    // -- string ops: concat / split (bd-c833a8) ----------------------------

    #[test]
    fn concat_folds_string_operands() {
        assert_eq!(
            reduce(
                ReduceOp::Concat,
                &[
                    Value::string("foo"),
                    Value::string("bar"),
                    Value::string("baz"),
                ],
            ),
            Ok(Value::string("foobarbaz"))
        );
        // Variadic: empty operand set yields the empty string.
        assert_eq!(reduce(ReduceOp::Concat, &[]), Ok(Value::string("")));
    }

    #[test]
    fn split_separates_into_a_list() {
        assert_eq!(
            reduce(
                ReduceOp::Split,
                &[Value::string("a,b,c"), Value::string(",")],
            ),
            Ok(Value::List(vec![
                Value::string("a"),
                Value::string("b"),
                Value::string("c"),
            ]))
        );
    }

    #[test]
    fn split_empty_separator_yields_characters() {
        assert_eq!(
            reduce(ReduceOp::Split, &[Value::string("ab"), Value::string("")]),
            Ok(Value::List(vec![Value::string("a"), Value::string("b")]))
        );
    }

    #[test]
    fn split_requires_exactly_two_operands() {
        assert!(matches!(
            reduce(ReduceOp::Split, &[Value::string("a,b")]),
            Err(RealiseError::Arity { got: 1, .. })
        ));
    }

    // -- template (bd-1779cd) ----------------------------------------------

    #[test]
    fn template_bare_percent_is_operand_zero() {
        // SPEC `not` operator: template "not %" over one operand.
        assert_eq!(
            template("not %", &[Value::string("foo")], "\n"),
            Value::string("not foo")
        );
    }

    #[test]
    fn template_indexed_operands() {
        assert_eq!(
            template(
                "%0 then %1",
                &[Value::string("a"), Value::string("b")],
                "\n"
            ),
            Value::string("a then b")
        );
        // Out-of-range index contributes nothing.
        assert_eq!(
            template("[%5]", &[Value::string("a")], "\n"),
            Value::string("[]")
        );
    }

    #[test]
    fn template_literal_percent() {
        assert_eq!(
            template("100%% done", &[], "\n"),
            Value::string("100% done")
        );
    }

    #[test]
    fn template_renders_list_operand_with_sep() {
        let list = Value::list(vec![Value::string("a"), Value::string("b")]);
        assert_eq!(template("<%>", &[list], " "), Value::string("<a b>"));
    }

    // -- join (bd-710166) --------------------------------------------------

    #[test]
    fn join_variadic_with_separator() {
        // SPEC `and` operator: join " and " over the operands.
        let operands = vec![Value::string("a"), Value::string("b"), Value::string("c")];
        assert_eq!(
            join(&operands, " and ", "\n"),
            Value::string("a and b and c")
        );
    }

    #[test]
    fn join_single_and_empty() {
        assert_eq!(
            join(&[Value::string("solo")], " and ", "\n"),
            Value::string("solo")
        );
        assert_eq!(join(&[], " and ", "\n"), Value::string(""));
    }

    #[test]
    fn join_renders_mixed_value_types() {
        let operands = vec![Value::string("n"), Value::number(2.0), Value::bool(true)];
        assert_eq!(join(&operands, "|", "\n"), Value::string("n|2|true"));
    }
}
