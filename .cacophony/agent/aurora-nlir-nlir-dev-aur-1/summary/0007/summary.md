# Session summary — det-echo verification: SPEC `_` echo op end-to-end

## Goal

Confirm the full deterministic SPEC `tests:` surface is green now that msm-0's
lexer fix (bd-ebf385) lets the `_` echo operator tokenise. Switch my command-
realisation eval test from the `@` workaround sigil back to the real SPEC `_`
echo operator and verify det-echo (`xxx_2` → "xxx xxx") passes end-to-end.

## Bead(s)

- (verification of `bd-ebf385` — msm-0's lexer `_`-tokenise fix)
- (follow-up to my `bd-3c1e6d` command realisation — now tested with the SPEC op)

## Before state

- Failing tests: none.
- My command-realisation eval test used a `@` sigil workaround because the SPEC
  `_` echo operator could not lex (lex_bare consumed `_` mid-token). det-echo was
  the one deterministic SPEC test not exercised with its real operator.

## After state

- Failing tests: none; 191 lib tests.
- `src/eval.rs` test config's echo operator is back to `op: "_"` (the SPEC sigil),
  and `command_realisation_runs_under_bash` now asserts `det("xxx_2") == "xxx xxx"`
  — det-echo end-to-end. The whole deterministic SPEC surface (det-echo/assign/sep
  included) is green.
- `cargo fmt --check`, `cargo clippy --all-targets -- -D warnings`, full test all
  clean (CI parity).

## Diff summary

- Code/content commits: pending final squash SHA from the reintegration receipt.
- Files touched: `src/eval.rs` (test-only: echo op `@`→`_`, test input `xxx@2`→`xxx_2`).
- Tests: 0 net (one test's operator + input made SPEC-faithful).
- Behavioural delta: none (test fidelity only); confirms bd-ebf385 works with the
  evaluator's command realisation.

## Embedded artefacts

- None this session.

## Operator-takeaway

The deterministic evaluation surface is now fully green with SPEC-faithful
operators, det-echo included — a nice cross-agent close-out of the `_` echo path
(msm-0 fixed the lexer, my evaluator's command realisation drives it). The
remaining eval work is LLM-mode realisation (waiting on aur-2's llm::realise_llm
helper — a one-call wire on my side) and the parallelism epic (after LLM
realisation).
