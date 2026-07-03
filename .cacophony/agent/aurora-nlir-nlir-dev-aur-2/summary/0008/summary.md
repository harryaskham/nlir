# Session summary — LLM NLIR_ var assembly (bd-e9983b)

## Goal

Assemble the `${NLIR_*}` variable environment that a model's message/command
templates reference, and provide the substitution the anthropic backend needs.
This is the piece that stitches the `%`-filled prompt and the resolved prompt
fragments into the final variable set (NLIR_PROMPT + system/structured/
unstructured), plus the `NLIR_ARGS` bash array for command backends.

## Bead(s)

- `bd-e9983b` — LLM: NLIR_ var assembly
- parent: `bd-b71b0b` — LLM epic (label `llm`)
- composes `bd-a47a02` (% substitution) + `bd-b9a977` (prompt fragments)

## Before state

- Failing tests: none. `src/llm.rs` had resolution, extraction, command backend,
  `%` substitution, and prompt fragments — but nothing combined them into the
  `${NLIR_*}` env set or expanded `${NLIR_*}` in a template.
- 129 lib tests green.

## After state

- Failing tests: none. 134 lib tests green (`cargo test --lib`), fmt/clippy clean.
- `assemble_nlir_vars`, `substitute_nlir_vars`, `nlir_args_declaration` +
  `NLIR_PROMPT_VAR` / `NLIR_ARGS_VAR` consts.

## Diff summary

- Code/content commit: `0d324f3` (final landed squash SHA from the reintegration
  receipt).
- Files touched: `src/llm.rs` only (3 fns + 2 consts + 4 tests).
- Tests: +4 (assemble adds NLIR_PROMPT to fragments; `${NAME}` expansion; unknown
  + unterminated `${` stay literal; NLIR_ARGS shell-quoting incl. embedded quote).
- Behavioural delta: the scalar `${NLIR_*}` set can now be assembled and expanded
  into anthropic message templates; command backends get a shell-quoted
  `NLIR_ARGS=(…)` declaration (bash expands `${NLIR_*}` itself).

## Operator-takeaway

The split-by-transport is the important call: the `command` backend runs under
bash, so it must NOT be Rust-substituted — bash expands `${NLIR_*}` including the
`${NLIR_ARGS[k]}` array form, which a scalar string substitution cannot do; the
`anthropic_messages` backend is a raw HTTP call, so its templates ARE
Rust-substituted here. Unknown `${…}` refs are left literal (not emptied) to
avoid silently blanking a real value. With resolution + fragments + %-fill +
assembly + command backend + extraction all landed, only the anthropic HTTP
backend (bd-d1a328) remains before the LLM coercion fallback (bd-ecb930) can land.
