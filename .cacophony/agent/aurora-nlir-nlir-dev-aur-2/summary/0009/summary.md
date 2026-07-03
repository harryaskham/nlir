# Session summary — LLM anthropic_messages backend (bd-d1a328)

## Goal

Add the second (and primary) LLM model backend: a direct HTTP client for the
Anthropic Messages API. It turns a resolved `anthropic_messages` model config +
the assembled `${NLIR_*}` variables into a POST, then extracts the result — the
piece that lets `llm`-mode realisation actually call a hosted model.

## Bead(s)

- `bd-d1a328` — LLM: anthropic_messages backend
- parent: `bd-b71b0b` — LLM epic (label `llm`)
- composes the whole pipeline: resolve_model + substitute_operands +
  resolve_prompt_fragments + assemble/substitute_nlir_vars + extract_result

## Before state

- Failing tests: none. `src/llm.rs` had the command backend + full prompt
  pipeline + extraction, but no HTTP model backend. `ureq` was only a transitive
  dependency.
- 134 lib tests green.

## After state

- Failing tests: none. 152 lib tests green (`cargo test --lib`), fmt clean.
- `llm::run_anthropic_backend(model, vars) -> Result<String, AnthropicError>`,
  with request builder + response text extraction; `ureq = 2` added as a direct
  dep.

## Diff summary

- Code/content commit: `8bd101c` (final landed squash SHA from the reintegration
  receipt).
- Files touched: `src/llm.rs` (backend + 5 tests + a one-shot mock HTTP server),
  `Cargo.toml` (+`ureq`), `Cargo.lock`.
- Tests: +5 via a local `TcpListener` mock (text + json extraction, 400 status
  error, no-text bad response, missing-config short-circuit; the text test also
  asserts POST /messages with the version/api-key headers and substituted prompt).
- Behavioural delta: `anthropic_messages` models can now be invoked over HTTP;
  `role:system` messages hoist to the top-level `system` field, `output_config`
  merges into the body, and the response's `content[].text` is extracted then run
  through `extract_result`.

## Operator-takeaway

The backend is deliberately config-driven at the API boundary: it owns the
mechanics (system-message hoisting, headers, response `content[].text`
extraction) but delegates the exact structured-output/`max_tokens` shape to the
model's `output_config`, which is merged into the request body — so the API
contract can evolve in config without code changes, and there is no hardcoded
Anthropic structured-output param to rot. Tests use a one-shot local HTTP mock
(no network, no key), which proves request/response mechanics without asserting
live-API semantics. Both backends now exist, so the LLM coercion fallback
(bd-ecb930) — the last piece of the types vertical — is fully unblocked.
