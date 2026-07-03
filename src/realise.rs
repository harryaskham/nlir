//! nlir deterministic operator realisation (SPEC §Modes).
//!
//! An operator is realised either deterministically (no network) or via an LLM.
//! This module holds the **deterministic** string/number realisations the
//! evaluator (bd-2b226d) calls after it has resolved and coerced an operator's
//! operands:
//!
//! - [`reduce`] — numeric reduction (`+ - * / **`), SPEC `reduce:` (bd-fa5ee2).
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
    let nums = numbers(op, operands)?;
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
    };
    Ok(Value::number(result))
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
