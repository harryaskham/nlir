# Session summary — LLM model resolution (bd-f0d357)

## Goal

Open the LLM realisation vertical with its one network-free piece — model
resolution — because the remaining coercion beads (bd-ecb930 LLM fallback,
bd-876367 caching) and the eval `llm` realisation all need to know *which*
configured model backend to call before any HTTP/subprocess work. Keep it a pure
config-resolution function so it lands and unblocks without touching the network.

## Goal context

The types lane's remaining beads are gated on the (previously unowned) LLM
backend; taking its first self-contained bead is the lane-unblocking move.

## Bead(s)

- `bd-f0d357` — LLM: model resolution
- parent: `bd-b71b0b` — LLM epic (label `llm`)

## Before state

- Failing tests: none. No `llm` module existed; config carried `models:`
  (alias→`ModelConfig`), `defaults.model`, per-operator `model:`, and a `--model`
  override, but nothing resolved them to a backend.
- 64 lib tests green on main after the coercion beads landed.

## After state

- Failing tests: none. 87 lib tests green (`cargo test --lib`), fmt clean.
- New `src/llm.rs` with `resolve_model(config, operator_model, cli_model)
  -> Result<(&str, &ModelConfig), ModelResolveError>` and a
  `ModelResolveError` (NoModel / UnknownModel) with Display + Error.

## Diff summary

- Code/content commit: `c6936b4` (final landed squash SHA from the reintegration
  receipt).
- Files touched: `src/llm.rs` (new), `src/lib.rs` (+1: `pub mod llm;`).
- Tests: +6 (operator > cli > defaults precedence; `NoModel`; `UnknownModel`
  from operator and cli sources; error-message content).
- Behavioural delta: model-alias resolution now exists. Precedence is operator
  `model:` → `--model` → `defaults.model`; the resolved alias must be a `models:`
  entry or it is a loud `UnknownModel` error. `--model` shares the default slot
  (overriding `defaults.model`) while operator `model:` still wins.

## Operator-takeaway

This is the seam every `llm`-mode caller routes through: coercion's LLM fallback
and eval's `llm` realisation both start by calling `resolve_model` to pick a
backend, then assemble the prompt and invoke it. The `--model`-overrides-default-
but-operator-model-wins precedence is the one non-obvious decision — it lets an
operator pin `sonnet` for `&` while `--model haiku` still re-points everything
else. The backend calls (anthropic HTTP / command subprocess), prompt assembly,
and result extraction are the next `llm` beads.
