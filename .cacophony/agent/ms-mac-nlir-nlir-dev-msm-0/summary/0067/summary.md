# Session summary — all-path evaluator recursion guard

## Goal

Turn bd-14402e's formerly latent stack-overflow gap into a tested runtime safety boundary now that do-N composition makes runtime-built `FormApply` trees reachable, while reconciling already-landed beads surfaced by the auto-claim queue instead of duplicating their work.

## Bead(s)

- `bd-14402e` — Runtime-built FormApply argument recursion can outrun the arg-frame-depth guard.
- `bd-3a589a` — Closure reconciliation only; self-verify deep-dive already landed at `0acd349`.
- `bd-429d87` — Closure reconciliation only; semantic-access reliability SPEC caveat already landed at `38f725bd`.
- `bd-8350f0` — Closure reconciliation only; composable semantic-operators deep-dive already landed at `b8e52c7`.

## Before state

- Evaluation only bounded positional argument-frame depth. `eval_form_apply` recursively evaluated every argument before pushing that frame, so a runtime-built nested FormApply tree could grow the native call stack while `arg_frames.len()` remained shallow.
- Do-N could allocate an arbitrarily large nested runtime AST from `{form}_N` before evaluation had a chance to reject it.
- The bead description called the path unreachable because `_` once shadowed form composition; current main now ships and documents `({form}_N)%seed`, so that premise was stale.
- Three auto-claimed open beads already had their own bead footers and deliverables on true main but had never been closed.

## After state

- Every sync and async evaluator entry uses one RAII depth guard, independent of arg-frame timing. The guard owns an `Rc<Cell<usize>>`, so it resets on normal return, errors, and cancellation of an async future.
- A directly constructed 101-deep runtime FormApply chain now returns a clean `evaluation nested too deep` error in both sync and async paths instead of risking native stack overflow.
- Do-N construction is capped at 64 applications. `({$0+1}_64)%0` returns `64`; count 65 errors before building the nested AST.
- README, SPEC, cookbook, and generated CLI help document the 64-application boundary and the independent all-path evaluator guard.
- The three leaked beads were independently verified against GitHub main and closed with their existing implementation SHAs; no duplicate code was written.

## Diff summary

- Code/content commit: `ba7d048` (`bd-14402e`). Final landed squash SHA will come from the reintegration receipt.
- Summary artefact commit: intentionally omitted; this file must not self-reference its own mutable SHA.
- Files touched: `src/eval.rs`, `src/main.rs`, `SPEC.md`, `README.md`, `docs/cookbook.md`.
- Tests: new sync+async direct-AST depth regression and do-N 64/65 boundary regression; 65/65 eval-module tests; 187/187 config tests; `cargo clippy --lib -- -D warnings`; debug binary build; rustfmt and diff checks; direct CLI boundary probe.
- Behavioural delta: runtime-generated expression trees can no longer bypass recursion safety by nesting inside pre-frame argument evaluation, and pathological do-N counts cannot allocate huge ASTs first.

## Operator-takeaway

The old form-cycle guard watched the wrong proxy for this path: argument frames appear only after arguments finish. Safety now follows evaluator recursion itself, while do-N stops oversized trees at construction, so both the general mechanism and its current producer fail cleanly.
