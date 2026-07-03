# Session summary — fix --parallelism flag→scheduler wiring

## Goal

While driving nlir in LLM mode (operator directive), fix the --parallelism CLI
flag: it was resolved into settings then never applied, so the DAG scheduler
always used config.defaults.parallelism and the flag had no effect (msm-0's note
on bd-149949).

## Bead(s)

- bd-e9dedc — parallelism CLI flag resolved then dropped: override never reaches the scheduler
- (follow-up to bd-149949; the HTTP-serialization part of that bead is confirmed external, not a nlir bug)

## Before state

- `nlir --parallelism 1 -e '~a&~b&~c'` (sleep-2s command op) ran in ~2s
  (concurrent) — the flag was ignored; only config.defaults.parallelism applied.

## After state

- main.rs::resolve_config now applies `cfg.defaults.parallelism = cli.parallelism.max(1)`
  when the flag is set, at the single choke point all eval paths (run_eval,
  run_repl, test runner) share. Respects the frozen `evaluate(expr,&Config,&mut
  Context,Mode)` signature — the override flows via the config the Evaluator
  already reads, no API change.
- Verified: `~a&~b&~c` with a sleep-2s command operator → default(8)=2s
  (concurrent), --parallelism 1=6s (sequential), --parallelism 2=4s (chunked 2+1).
- fmt + clippy -D warnings + 204 lib tests all clean.

## Diff summary

- Files: src/main.rs (resolve_config, +6 lines incl. comment).
- Tests: none added — the parallelism=1→sequential eval behaviour is already
  locked by the det_seq cache test; the cli→config wiring is a trivial config
  mutation verified by the sleep-command timing check (a timing-based integration
  test is deliberately avoided per the no-timing-tests convention).
- Behavioural delta: --parallelism N now actually bounds scheduler concurrency.

## Embedded artefacts

- None.

## Operator-takeaway

Driving nlir end-to-end in LLM mode surfaced this: the whole DAG scheduler and
command backends parallelize correctly (verified live: 3 concurrent claude
subject-extractions ~13s; sleep-command 3-way = 2s), but the --parallelism CLI
knob was silently inert because the resolved value never reached the Evaluator.
Now fixed and verified across parallelism 1/2/8. This was one of several findings
from the LLM-mode driving session (others: math precedence needs explicit config
priorities → msm-0 landed bd-699adf; the M^N message-range is unreachable →
msm-0 taking bd-c3fc30; LLM operand coercion wiring → msm-0 landed bd-ba9f85).
