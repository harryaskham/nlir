# Session summary — parallelism: DAG scheduler (concurrent operand eval)

## Goal

Implement the SPEC concurrency feature — independent LLM/command operand subtrees
evaluate concurrently, bounded by `defaults.parallelism` — via `std::thread::scope`
(operator-chosen, no rayon dep), keeping the working sequential evaluator intact
and adding a parallel read-only path alongside.

## Bead(s)

- `bd-780dbf` — Parallelism: DAG scheduler
- `bd-0d9f66` — Parallelism: context-write serialization
- `bd-f66c32` — Parallelism: backtick forced-serial subtree
- (parent epic: `bd-a32894`)

## Before state

- Failing tests: none (main green).
- The evaluator was a fully-sequential `&mut self` tree-walk; independent LLM/
  command subcalls ran one at a time.

## After state

- Failing tests: none; 202 lib tests (+1 concurrency-correctness test; cache
  tests moved to a sequential config).
- `src/eval.rs`:
  - `Evaluator` gains `parallelism` (from `config.defaults.parallelism`) and its
    realisation cache is now a `Mutex<HashMap>` shared across threads.
  - The realisation helpers (`realise`, `realise_cached`, `parenthesise_grouped`,
    `realise_command`) are now free functions so the sequential eval and the
    parallel path share them.
  - `is_parallel_safe(expr)`: a subtree is parallel-safe iff it only reads context
    and computes — NO `Assign` (context write), NO `$`/`$N` (stack), NO nullary op
    (stack pop). This inherently serializes context-writing subtrees (bd-0d9f66)
    and lets a backtick `Serial` operand parallelize with siblings while running
    serially inside (bd-f66c32).
  - `eval_apply`: when an op has >1 operand, `parallelism>1`, and every operand is
    parallel-safe, the operands evaluate concurrently via `std::thread::scope`
    (chunked by `parallelism`) through `eval_parallel_safe` (a read-only eval
    sharing `&Config`/`&Context`/`&Mutex<cache>`); otherwise the sequential path
    runs unchanged.
- `cargo fmt --check`, `cargo clippy --all-targets -- -D warnings`, full test all
  clean (CI parity).

## Diff summary

- Code/content commits: pending final squash SHA from the reintegration receipt.
- Files touched: `src/eval.rs` (Mutex cache + parallelism field; free realise fns;
  is_parallel_safe / eval_parallel_safe / eval_operands_parallel; concurrent
  dispatch; +3 tests reworked/added).
- Tests: +1 concurrency-correctness (`#a&#b&#c` and grouped command operands
  compose correctly under parallel eval); cache-dedup tests moved to a
  `parallelism:1` config.
- Behavioural delta: independent side-effect-free operand subtrees now evaluate
  concurrently, bounded by parallelism; results are identical to sequential
  (concurrency is transparent). Context writes and stack access force sequential.

## Embedded artefacts

- None this session.

## Operator-takeaway

nlir now runs its independent LLM/command subcalls concurrently — the headline SPEC
DAG feature — with the sequential evaluator left intact and a parallel read-only
path added alongside (low-risk). Two deliberate limitations, noted for follow-up:
(1) parallelization happens only at the TOP level of each `Apply` (a parallelized
operand evaluates sequentially inside), which bounds total concurrency simply but
doesn't parallelize deeply-nested independent calls — a nested-scheduler refinement
could lift this; (2) two truly-simultaneous identical subcalls on different threads
may both miss the shared cache and compute (in-flight dedup isn't attempted;
sequential repeats always dedup). Both are safe and correct — just not maximally
parallel. This completes the parallelism epic's core and, with it, the nlir
evaluator is feature-complete including concurrency.
