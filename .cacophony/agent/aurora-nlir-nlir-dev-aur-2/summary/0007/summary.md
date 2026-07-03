# Session summary — LLM prompt fragments (bd-b9a977)

## Goal

Resolve the configured `prompts:` fragments (system / structured / unstructured)
into the named environment variables the model templates reference as
`${NLIR_SYSTEM_PROMPT}` etc., honouring process-env overrides. This is the second
piece of the prompt pipeline: it produces the fragment vars that the `${NLIR_*}`
assembly step (bd-e9983b) then stitches into the final prompt.

## Bead(s)

- `bd-b9a977` — LLM: prompt fragments
- parent: `bd-b71b0b` — LLM epic (label `llm`)
- same module `src/llm.rs`

## Before state

- Failing tests: none. `src/llm.rs` had model resolution, extraction, the command
  backend, and `%` substitution, but nothing resolved the `prompts:` fragments.
- 124 lib tests green.

## After state

- Failing tests: none. 129 lib tests green (`cargo test --lib`), fmt/clippy clean.
- `llm::resolve_prompt_fragments(prompts, lookup) -> BTreeMap<String, String>`
  maps each fragment's `env:` name to its effective text.

## Diff summary

- Code/content commit: `5d84954` (final landed squash SHA from the reintegration
  receipt).
- Files touched: `src/llm.rs` only (resolve fn + 4 tests; imports `BTreeMap`,
  `PromptDef`).
- Tests: +4 (env-named export; env override wins over text; empty when neither
  env value nor text; fragment with no `env:` name skipped).
- Behavioural delta: `prompts:` fragments become `name -> text` env vars; a set
  process-env var overrides the config `text:`; nameless fragments are skipped.

## Operator-takeaway

The override direction is the key contract: a process-env value *wins* over the
config `text:` (so a script can export `NLIR_SYSTEM_PROMPT` to override the
config for one run), and the `lookup` is injected rather than reading
`std::env` directly, keeping the resolver hermetic and testable (and clear of the
crate's `unsafe_code = forbid` env-mutation rule). Next is bd-e9983b: combine
these fragment vars with `NLIR_PROMPT` (the `%`-filled prompt) and `NLIR_ARGS`
(operands) and substitute `${NLIR_*}` into the model's messages/command — after
which the anthropic backend and the LLM coercion fallback can land.
