//! nlir evaluation stack (SPEC §Builtins: Sequencing & stack).
//!
//! The stack is the second runtime namespace (alongside the context object): a
//! run-scoped stack of typed [`Value`]s.
//!
//! - **`;`** evaluates a statement and **pushes** its value.
//! - **`$`** peeks the top value; **`$N`** peeks by index — `$0` is the bottom,
//!   negatives count from the top (`$-1` = top) — neither pops.
//! - A **nullary** operator (a config op given no operands) **pops** from the
//!   stack: an arity-`k` op pops `k` values, a variadic op pops all.
//!
//! This is a pure data structure with no evaluator wiring; the evaluator
//! (bd-2b226d) owns a `Stack` instance and drives it as it walks the DAG.
//! bd-d4631b.

use crate::value::Value;

/// The run-scoped evaluation stack of typed values.
#[derive(Debug, Clone, Default, PartialEq)]
pub struct Stack {
    /// Bottom-to-top: `items[0]` is the bottom (`$0`), `items.last()` the top
    /// (`$` / `$-1`).
    items: Vec<Value>,
}

impl Stack {
    /// A new empty stack.
    #[must_use]
    pub fn new() -> Self {
        Self::default()
    }

    /// `;` — push a value onto the top of the stack.
    pub fn push(&mut self, value: Value) {
        self.items.push(value);
    }

    /// The number of values on the stack.
    #[must_use]
    pub fn len(&self) -> usize {
        self.items.len()
    }

    /// Whether the stack is empty.
    #[must_use]
    pub fn is_empty(&self) -> bool {
        self.items.is_empty()
    }

    /// A read-only view of the stack, bottom-to-top.
    #[must_use]
    pub fn as_slice(&self) -> &[Value] {
        &self.items
    }

    /// `$` — peek the top (most recently pushed) value without popping. `None`
    /// on an empty stack.
    #[must_use]
    pub fn peek(&self) -> Option<&Value> {
        self.items.last()
    }

    /// `$N` — peek by index without popping: `$0` is the bottom, positive
    /// indices count up from the bottom, negatives from the top (`$-1` = top).
    /// `None` when the index is out of range.
    #[must_use]
    pub fn peek_index(&self, index: i64) -> Option<&Value> {
        crate::index::resolve_index(self.items.len(), index).map(|i| &self.items[i])
    }

    /// Pop the single top value (`None` on an empty stack).
    pub fn pop(&mut self) -> Option<Value> {
        self.items.pop()
    }

    /// nullary-pop for an arity-`k` operator: pop the top `k` values, returned
    /// bottom-most-first (push order, so operands read left-to-right). `None`
    /// when fewer than `k` values are present (the stack is left untouched).
    pub fn pop_n(&mut self, k: usize) -> Option<Vec<Value>> {
        if self.items.len() < k {
            return None;
        }
        let at = self.items.len() - k;
        Some(self.items.split_off(at))
    }

    /// nullary-pop for a variadic operator: pop and return every value, in push
    /// order (bottom-most first). Empties the stack.
    pub fn pop_all(&mut self) -> Vec<Value> {
        std::mem::take(&mut self.items)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn stack_of(values: &[i64]) -> Stack {
        let mut s = Stack::new();
        for &v in values {
            s.push(Value::number(v as f64));
        }
        s
    }

    #[test]
    fn push_peek_and_len() {
        let mut s = Stack::new();
        assert!(s.is_empty());
        assert_eq!(s.peek(), None);
        s.push(Value::string("a"));
        s.push(Value::string("b"));
        assert_eq!(s.len(), 2);
        // `$` peeks the top (most recently pushed).
        assert_eq!(s.peek(), Some(&Value::string("b")));
        // Peek does not pop.
        assert_eq!(s.len(), 2);
    }

    #[test]
    fn peek_index_bottom_is_zero_top_is_negative_one() {
        let s = stack_of(&[10, 20, 30]); // bottom→top: 10, 20, 30
        // `$0` bottom.
        assert_eq!(s.peek_index(0), Some(&Value::number(10.0)));
        assert_eq!(s.peek_index(1), Some(&Value::number(20.0)));
        assert_eq!(s.peek_index(2), Some(&Value::number(30.0)));
        // `$-1` top, `$-3` bottom.
        assert_eq!(s.peek_index(-1), Some(&Value::number(30.0)));
        assert_eq!(s.peek_index(-3), Some(&Value::number(10.0)));
        // Out of range.
        assert_eq!(s.peek_index(3), None);
        assert_eq!(s.peek_index(-4), None);
        // Consistent with `$` for the top.
        assert_eq!(s.peek_index(-1), s.peek());
    }

    #[test]
    fn peek_index_on_empty_is_none() {
        let s = Stack::new();
        assert_eq!(s.peek_index(0), None);
        assert_eq!(s.peek_index(-1), None);
    }

    #[test]
    fn pop_returns_top() {
        let mut s = stack_of(&[1, 2, 3]);
        assert_eq!(s.pop(), Some(Value::number(3.0)));
        assert_eq!(s.pop(), Some(Value::number(2.0)));
        assert_eq!(s.len(), 1);
    }

    #[test]
    fn pop_n_returns_k_in_push_order_and_is_atomic() {
        let mut s = stack_of(&[1, 2, 3, 4]);
        // Pop the top two, returned bottom-most-first (push order): [3, 4].
        let popped = s.pop_n(2).expect("two available");
        assert_eq!(popped, vec![Value::number(3.0), Value::number(4.0)]);
        assert_eq!(s.as_slice(), &[Value::number(1.0), Value::number(2.0)]);
        // Requesting more than present pops nothing and returns None.
        assert_eq!(s.pop_n(5), None);
        assert_eq!(s.len(), 2);
        // pop_n(0) is an empty pop.
        assert_eq!(s.pop_n(0), Some(vec![]));
        assert_eq!(s.len(), 2);
    }

    #[test]
    fn pop_all_drains_in_push_order() {
        let mut s = stack_of(&[1, 2, 3]);
        assert_eq!(
            s.pop_all(),
            vec![Value::number(1.0), Value::number(2.0), Value::number(3.0)]
        );
        assert!(s.is_empty());
        assert_eq!(Stack::new().pop_all(), vec![]);
    }
}
