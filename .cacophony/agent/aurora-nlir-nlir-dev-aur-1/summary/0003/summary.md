# Session summary — deterministic realisation: reduce + template + join

## Goal

Implement the deterministic operator-realisation layer (SPEC §Modes): the pure
functions the evaluator calls to realise an operator without an LLM once its
operands are resolved and coerced. This is the leaf layer beneath the DAG
evaluator — numeric reduction, template substitution, and variadic join — landed
independently so the evaluator (bd-2b226d, now unblocked by the parser
statement-split) can compose them.

## Bead(s)

- `bd-fa5ee2` — Eval: numeric reduce builtins (`+ - * / **`)
- `bd-1779cd` — Eval: template realisation (`%`, `%N`, `%%`)
- `bd-710166` — Eval: join realisation (variadic)
- (parent epic: `bd-2b226d` — evaluator)

## Before state

- Failing tests: none (main green).
- No realisation layer existed; `OperatorConfig` carried `template`/`join`/
  `reduce`/`command` fields but nothing consumed them to produce a `Value`.
- Landed foundations used: `value::Value` and `config::ReduceOp`.

## After state

- Failing tests: none.
- New `src/realise.rs` (registered in `src/lib.rs`): `reduce` (numeric, fallible),
  `template` (`%`/`%N`/`%%`), `join` (variadic separator). 12 unit tests, all
  passing. `cargo fmt --check` clean; `cargo clippy --all-targets` clean for the
  new module.

## Diff summary

- Code/content commits: pending final squash SHA from the reintegration receipt.
- Files touched: `src/realise.rs` (new), `src/lib.rs` (+`pub mod realise;`).
- Tests: +12 (reduce fold/binary/div-by-zero/arity/non-number; template
  bare/indexed/literal/list-render; join variadic/single/empty/mixed-type).
- Behavioural delta: nlir now has the deterministic realisation functions as a
  pure library the evaluator dispatches to by `OperatorConfig` field.

## Embedded artefacts

- None this session.

## Operator-takeaway

The `det` realisation leaves are done, so the evaluator (bd-168ef8, unblocked by
the landed parser statement-split) can resolve operands → coerce → dispatch to
these by operator config field. Remaining eval gaps: the evaluator DAG walk,
`command:` realisation (bd-3c1e6d), nullary-pop (bd-9aac32), list rendering/spread
(bd-02a795). My context beads (assignment bd-c85dee, `$name` read bd-91e573)
unblock as msm-0 lands the parser Assign node + the evaluator comes up.
