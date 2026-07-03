# Session summary — realise_llm helper, the eval↔llm seam (bd-dc3c72)

## Goal

Provide the single high-level LLM-mode realisation helper the evaluator needs, so
its `realise()` `Mode::Llm` arm (currently `Unsupported`) becomes a one-call wire.
This is the seam where my LLM lane meets aur-1's eval lane — I own the llm.rs
helper, aur-1 wires it into eval.rs.

## Bead(s)

- `bd-dc3c72` — LLM: realise_llm helper (eval↔llm realisation seam); parent LLM
  epic `bd-b71b0b`. Filed + owned via the eval↔llm coordination with aur-1.

## Before state

- Failing tests: none. All LLM primitives existed (resolve_model, prompt
  pipeline, both backends, extract_result) but nothing composed them into one
  call; the evaluator's llm-mode arm returned `Unsupported`.
- 185 lib tests green.

## After state

- Failing tests: none. 190 lib tests green (`cargo test --all`); full CI gate
  (fmt, clippy `-D warnings`, test) clean.
- `llm::realise_llm(model_alias, prompt_template, operands, &Config, cli_model,
  env_lookup) -> Result<String, RealiseError>`.

## Diff summary

- Code/content commit: `49c8828` (final landed squash SHA from the reintegration
  receipt).
- Files touched: `src/llm.rs` only (helper + RealiseError + 5 tests).
- Tests: +5 (command prompt-fill reaches the backend; `${NLIR_ARGS[k]}` array
  indexing; defaults-model fallback; unknown-model error; anthropic dispatch via
  the mock server).
- Behavioural delta: one call now resolves the model, fills the prompt, assembles
  `${NLIR_*}`, dispatches the right backend, and returns the extracted result.

## Operator-takeaway

The signature was negotiated with aur-1 to drop straight into `eval::realise()`:
returns a raw `String` (they wrap in `Value::string`), and takes the operator's
`model:` as `Option<&str>` so `None` falls back to `cli_model` → `defaults.model`
via `resolve_model`'s precedence. The one non-obvious piece is command-operator
plumbing: `realise_llm` prepends the `NLIR_ARGS=(…)` bash array to the command so
operators like the SPEC `echo` (`${NLIR_ARGS[0]}`) work — that array can't be a
plain env var, so keeping it here (not in the evaluator) is what makes the seam a
true one-call wire. With this, llm-mode evaluation is unblocked end to end; aur-1
wires the eval.rs side and validates against the command-model path.
