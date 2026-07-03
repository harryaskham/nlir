# Session summary — eval: wire Mode::Llm realisation to llm::realise_llm

## Goal

Wire the evaluator's `Mode::Llm` realisation arm to aur-2's landed
`llm::realise_llm` helper — the last realisation path. With this, nlir realises
operators via LLM backends (command + anthropic) as well as deterministically,
completing the eval↔llm seam.

## Bead(s)

- `bd-3573aa` — Eval: wire Mode::Llm realisation to llm::realise_llm
- (composes aur-2's `bd-dc3c72` realise_llm helper)

## Before state

- Failing tests: none.
- `eval::Evaluator::realise()`'s `Mode::Llm` arm returned `EvalError::Unsupported`
  — llm-mode operators could not be realised even though the llm.rs backends and
  the `realise_llm` seam were landed.

## After state

- Failing tests: none; 193 lib tests.
- `src/eval.rs` `Mode::Llm` arm: if the operator has a `prompt:`, render the
  (grouped-parens-preserved) operands to `Vec<String>`, call
  `llm::realise_llm(op_cfg.model.as_deref(), prompt, &args, self.config, None,
  |n| std::env::var(n).ok())`, wrap the `Ok(String)` in `Value::string`, and map
  the `llm::RealiseError` into a new `EvalError::Llm(String)`. An llm op with no
  `prompt:` stays `Unsupported`.
- 3 tests via a deterministic command-type model (no network): backend reached
  (`x?` → "llm-said-hi"), prompt filled from operands (`!foo` →
  "negate: <text>foo</text>"), no-prompt → Unsupported + unknown-model → Llm error.
- `cargo fmt --check`, `cargo clippy --all-targets -- -D warnings`, full test all
  clean (CI parity).

## Diff summary

- Code/content commits: pending final squash SHA from the reintegration receipt.
- Files touched: `src/eval.rs` (EvalError::Llm + Mode::Llm arm + 3 tests, replacing
  the old "unsupported" placeholder test).
- Tests: +2 net (llm realisation via command model; prompt fill; no-prompt/unknown
  model), replacing the prior unsupported-placeholder test.
- Behavioural delta: the evaluator now realises operators in BOTH modes — det
  (reduce/template/join/command) and llm (model+prompt via anthropic/command).

## Embedded artefacts

- None this session.

## Operator-takeaway

The evaluator's realisation surface is now COMPLETE: deterministic AND llm modes
both work end-to-end. anthropic HTTP is exercised in llm.rs' own mock tests
(aur-2); my eval-side tests use a command-type model to stay offline/deterministic.
The remaining big eval piece is the parallelism epic (bd-780dbf DAG scheduler +
context-write serialization + backtick serial + subcall dedupe/cache) — now
genuinely worthwhile since llm/command subcalls are the slow paths worth running
concurrently. That's my next focused effort.
