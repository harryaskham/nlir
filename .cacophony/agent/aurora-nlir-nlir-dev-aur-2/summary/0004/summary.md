# Session summary — LLM result extraction (bd-275d8b)

## Goal

Add the shared result parser for the LLM realisation vertical: the pure function
that turns a backend's raw output into the final result string, handling both the
structured `json`/`result_field` shape and the raw-`text` shape, and surfacing
loud errors on malformed responses. It sits between the model backends and every
caller, so both the command and anthropic backends reuse one extraction path.

## Bead(s)

- `bd-275d8b` — LLM: result extraction
- parent: `bd-b71b0b` — LLM epic (label `llm`)
- follows `bd-f0d357` (model resolution), same module (`src/llm.rs`)

## Before state

- Failing tests: none. `src/llm.rs` held only `resolve_model`; nothing turned a
  backend's stdout/response into a result string.
- 87 lib tests green on main.

## After state

- Failing tests: none. 93 lib tests green (`cargo test --lib`), fmt/clippy clean.
- `llm::extract_result(raw, format, result_field) -> Result<String, ExtractError>`
  with `ExtractError` (InvalidJson / MissingResultField / NonScalarResult),
  Display + Error, and `DEFAULT_RESULT_FIELD = "result"`.

## Diff summary

- Code/content commit: `e059428` (final landed squash SHA from the reintegration
  receipt).
- Files touched: `src/llm.rs` only (extraction fn + ExtractError + 6 tests; use
  of `ModelFormat`).
- Tests: +6 (text trailing-newline strip; default + custom `result_field`;
  number/bool stringification; the three loud error cases).
- Behavioural delta: `text` returns stdout minus trailing newlines (shell `$(…)`
  convention); `json` reads `result_field` (JSON string verbatim; number/bool
  stringified so a coercion `{result: 5}` yields `"5"`); malformed JSON, a
  missing field, or a non-scalar value is a loud error.

## Operator-takeaway

Result extraction is deliberately backend-agnostic: `command` (bd-f5e007) and
`anthropic_messages` (bd-d1a328) both just produce raw output and hand it here,
so the json-vs-text result contract lives in exactly one place. The one design
call is that a JSON number/bool result is stringified rather than rejected — that
keeps the LLM *coercion* path working (a `{result: 5}` number-coercion response
becomes `"5"`, which the deterministic type layer then parses).
