# Session summary — deterministic type coercions (bd-456f12)

## Goal

Add the deterministic coercion layer of the Types vertical: the step that runs
*before* any LLM call to move a runtime `Value` between the four SPEC types
(string/number/bool/list) using pure, mechanical rules. Keep the interface shaped
so the LLM-fallback and loud-error beads compose on top without rework.

## Bead(s)

- `bd-456f12` — Types: deterministic coercions
- parent: `bd-957ff4` — Types epic (label `types`)
- builds on `bd-700306` — typed value model (landed earlier this session)

## Before state

- Failing tests: none. `Value` (bd-700306) existed with type tags, accessors,
  and `render`, but no coercion — nothing moved values between types.
- 54 lib tests green on main (`5c10b3f`).

## After state

- Failing tests: none. 59 lib tests green (`cargo test --lib`), fmt clean.
- `Value::coerce_deterministic(target, sep) -> Option<Value>` implements SPEC
  §Types & coercion steps 1–2; `None` signals "no deterministic rule — defer to
  the LLM fallback / loud-error layers".
- One pre-existing clippy warning remains in `config.rs:632` (draft bd-06ffd7);
  untouched here.

## Diff summary

- Code/content commit: `ed7b552` (final landed squash SHA from the reintegration
  receipt).
- Files touched: `src/value.rs` only (new method + 5 tests).
- Tests: +5 (identity; `→ string` for number/bool/list; `string → number` incl.
  whitespace tolerance and non-numeric `None`; `string → bool` true/false only;
  the `None`-deferral cases incl. `list → number`).
- Behavioural delta: values can now be deterministically coerced —
  `→ string` always succeeds (render, lists join `_sep`), `"1" → number`,
  `"true"/"false" → bool`; all other conversions return `None` for the next
  coercion layer. No existing behaviour changed.

## Operator-takeaway

The coercion contract is now `Option<Value>`: deterministic success is `Some`,
and `None` is the single, explicit hand-off point to the LLM fallback
(bd-ecb930) and the loud-error rule (bd-20df97, where `list → number` becomes a
hard error). That keeps the three coercion beads cleanly layered on one function
instead of tangling deterministic parsing, network calls, and error policy
together.
