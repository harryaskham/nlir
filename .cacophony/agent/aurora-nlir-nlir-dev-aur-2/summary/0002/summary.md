# Session summary — loud coercion errors + list→number (bd-20df97)

## Goal

Complete the deterministic slice of the Types vertical with the terminal
coercion behaviour: a single `coerce` entry point that raises a **loud error**
when a value cannot be produced as the required type, and enforces the SPEC rule
that `list → number` is *always* an error (never even attempted). Shape it so the
LLM coercion fallback (bd-ecb930) slots in cleanly once an LLM backend lands.

## Bead(s)

- `bd-20df97` — Types: loud coercion errors + `list → number` error
- parent: `bd-957ff4` — Types epic (label `types`)
- builds on `bd-700306` (value model) + `bd-456f12` (deterministic coercions),
  both landed earlier this session

## Before state

- Failing tests: none. `Value::coerce_deterministic -> Option<Value>` existed but
  there was no error type and no terminal coercion entry point; nothing enforced
  the `list → number` hard rule.
- 60 lib tests green on main after rebasing past the parser AST-dump landing.

## After state

- Failing tests: none. 64 lib tests green (`cargo test --lib`), fmt clean.
- `Value::coerce(target, sep) -> Result<Value, CoerceError>` is the terminal
  coercion: `list → number` → loud error; deterministic success → `Ok`;
  otherwise a loud `CoerceError`. The LLM fallback (bd-ecb930) has a documented
  insertion seam between the deterministic attempt and the error.
- New `CoerceError { from, to, kind, source }` with `ListToNumber` /
  `Unrepresentable` kinds, a bounded (≤80 char) source snippet, `Display`, and
  `std::error::Error`.

## Diff summary

- Code/content commit: `9430455` (final landed squash SHA from the reintegration
  receipt).
- Files touched: `src/value.rs` only (coerce method + CoerceError types + 4 tests).
- Tests: +4 (deterministic-backed `Ok` incl. `→ string` never errors;
  `list → number` loud error with typed fields + message; unrepresentable
  `string → number` / `string → bool`; bounded error snippet).
- Behavioural delta: values can now be coerced with loud errors on failure; no
  live caller yet (eval coercion wiring, bd-dd7b5e, is unlanded), so this is
  additive scaffolding.

## Operator-takeaway

The coercion trio is now two-thirds done and cleanly layered on one value type:
`coerce_deterministic` (Option) → `coerce` (Result, loud errors + the
`list → number` hard rule). Only the middle LLM step (bd-ecb930) remains, and it
is *blocked on the LLM backend* (epic bd-b71b0b, currently unowned) rather than
on anything in the types lane — so the types vertical is at a natural pause point
until the model-call surface exists. `list → number` is enforced structurally, so
it holds regardless of mode.
