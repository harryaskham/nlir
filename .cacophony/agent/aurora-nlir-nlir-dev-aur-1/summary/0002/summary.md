# Session summary — context runtime primitives: stack machine + $name interpolation

## Goal

Add the two context-epic runtime primitives that are implementable ahead of the
evaluator: the evaluation **stack** (the second runtime namespace) and bare
**`$name` interpolation** inside `"…"` strings. Both are pure, tested building
blocks the evaluator (bd-2b226d) will drive when it walks the DAG — continuing
the context lane on landed foundations (context store + value model) without
waiting on the evaluator.

## Bead(s)

- `bd-d4631b` — Context: stack machine
- `bd-22fa7e` — Context: double-quote $name interpolation
- (parent epic: `bd-7a1d2f` — context namespace)

## Before state

- Failing tests: none (main green).
- No evaluation stack type existed; `$`/`$N` had nowhere to resolve against.
  String interpolation (`"the subject is $k"`) was unimplemented.
- Landed foundations used: `value::Value` (aur-2), the context store
  (`src/context.rs`, this session).

## After state

- Failing tests: none.
- New `src/stack.rs` (registered in `src/lib.rs`): `Stack` over `value::Value`
  with push, peek (`$`), `peek_index` (`$N`: `$0` bottom, `$-1` top, negatives
  from the top), `pop`, `pop_n` (arity-k, push order, atomic), `pop_all`
  (variadic).
- `src/context.rs` extended: pure `interpolate(text, lookup)` (bare `$name`
  only — leaves `${…}`, `$N`, trailing `$`, and unresolved names literal) plus
  `Context::interpolate` convenience rendering context values (numbers without
  `.0`, lists joined with `_sep`).
- +8 tests (6 stack, 2 interpolation); context suite 16→18. `cargo fmt --check`
  clean; `cargo clippy --all-targets` clean for the new code.

## Diff summary

- Code/content commits: pending final squash SHA from the reintegration receipt.
- Files touched: `src/stack.rs` (new), `src/context.rs` (+interpolate/render),
  `src/lib.rs` (+`pub mod stack;`).
- Tests: +8 (stack push/peek/index/pop_n/pop_all bounds; interpolation bare-name
  vs `${…}`/`$N`/unresolved; context-store value rendering).
- Behavioural delta: nlir now has the eval stack primitive and `$name` string
  interpolation as pure library pieces; no evaluator wiring yet (the evaluator
  owns a `Stack` and supplies interpolation's `lookup`).

## Embedded artefacts

- None this session.

## Operator-takeaway

With the stack + interpolation landed, the context epic's remaining beads
(`$name` read greedy-resolution bd-91e573, `key=RHS` assignment bd-c85dee) are
mostly evaluator-wiring — the store `get`/`set`/write-through and these
primitives already exist, so they land when the evaluator (bd-2b226d) does. Minor
duplication noted: `Stack::resolve_index` and `messages::resolve_index` are the
same negative-index-from-end logic (filed as a low-priority dedup draft).
