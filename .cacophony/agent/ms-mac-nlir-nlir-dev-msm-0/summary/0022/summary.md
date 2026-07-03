# Session summary — nlir output: --dry-run (DAG, no calls) + --quiet

## Goal

Complete the modes/output flags: `--dry-run` prints the DAG and makes no calls;
`--quiet` prints the stdout result only (suppresses the stderr trace).

## Bead(s)

- `bd-e432fc` — Output: --dry-run (DAG + assembled prompts, no calls)
- `bd-d52b78` — Output: --quiet (suppress stderr trace; stdout result only)
- (parent epic: `bd-6cdfee` — modes/output)

## Before state

- `--dry-run` was ignored (run_eval evaluated normally, making calls); `--quiet` suppressed the run_eval trace but there was no dry-run path.
- Failing tests: none. 191 unit tests.

## After state

- Failing tests: none. 191 unit tests pass; clippy `-D warnings` clean; `cargo fmt --check` clean. Verified end-to-end.
- `run_eval` short-circuits to `run_dry_run` when `--dry-run`: it tokenises + parses `expr` into the DAG and prints it (the rendered program per statement) to stdout, making NO calls (no eval → no LLM request, no `command:` subprocess). The stderr note is suppressed by `--quiet`.
- `--quiet` prints stdout only across eval (result), dry-run (DAG), and test (suppresses per-test ok lines); errors still go to stderr.
- `nlir -e 'a&b&c' --dry-run` → stdout `(a & b & c)` + stderr "no calls made"; `--dry-run --quiet` → stdout `(1 + 2 + 3)` only.

## Diff summary

- Files touched: `src/main.rs` (`run_dry_run` helper; run_eval dry-run short-circuit).
- Behavioural delta: `--dry-run` is a safe no-calls DAG preview; `--quiet` is result-only.

## Operator-takeaway

`--dry-run` (DAG + no calls) and `--quiet` are done. The "assembled prompts"
half of `--dry-run` (SPEC: show the LLM prompts that WOULD be sent) is deferred:
Mode::Llm realisation currently returns Unsupported (aur-1 is wiring it pending
aur-2's llm helper), so there are no prompts to preview yet — filed as a
follow-on. Remaining CLI/output work: the REPL (bd-6a0ca8/bd-86b529/bd-c2ac59),
now unblocked since eval works.
