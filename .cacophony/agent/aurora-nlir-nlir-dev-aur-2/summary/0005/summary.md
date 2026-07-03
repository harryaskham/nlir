# Session summary — LLM command backend (bd-f5e007)

## Goal

Add the `type: command` model backend for the LLM realisation vertical: run a
model's `command:` template as a subprocess, capture its output, and turn it into
a result string. This is the first of the two backends and is fully testable
without any network, so it lands the "call a model" surface for command-driven
models (e.g. `claude … --print`, `pi … --print`).

## Bead(s)

- `bd-f5e007` — LLM: command backend
- parent: `bd-b71b0b` — LLM epic (label `llm`)
- builds on `bd-f0d357` (model resolution) + `bd-275d8b` (result extraction),
  same module `src/llm.rs`

## Before state

- Failing tests: none. `src/llm.rs` had model resolution + `extract_result`, but
  nothing actually invoked a model backend.
- ~93 lib tests green on the pre-rebase base (110 after rebasing on the swarm's
  landed parser/context/message work).

## After state

- Failing tests: none. 110 lib tests green (`cargo test --lib`), fmt/clippy clean.
- `llm::run_command_backend(model, env) -> Result<String, CommandError>` runs the
  `command:` under bash (inherit parent env + layer `env`), then `extract_result`.
- `CommandError` (NoCommand / Spawn / NonZeroExit{code,stderr} / Extract) with
  Display, `Error::source`, and `From<ExtractError>`.

## Diff summary

- Code/content commit: `73157fa` (final landed squash SHA from the reintegration
  receipt).
- Files touched: `src/llm.rs` only (backend fn + CommandError + 6 tests; added
  `use std::process::Command`).
- Tests: +6 (text stdout; json default + custom `result_field`; `${NLIR_*}` env
  export reaches the command; non-zero exit surfaces code + stderr; missing
  command; unparseable output → extract error).
- Behavioural delta: command-driven models can now be invoked. Runs under bash
  (SPEC command examples use bash array/arith syntax); prompt/`${NLIR_*}`
  assembly remains the caller's job (bd-e9983b).

## Operator-takeaway

The command backend is deliberately thin: spawn under bash, inherit the parent
environment (so `claude`/`pi`/credentials resolve), overlay the assembled
`${NLIR_*}` vars, and hand stdout to the shared `extract_result`. The one design
choice is bash-not-sh — the SPEC's `echo` operator uses `${NLIR_ARGS[0]}` array
indexing, which POSIX `sh` cannot do, so the prompt-assembly bead (bd-e9983b) can
rely on bash array semantics. Next: `%` operand substitution and the `${NLIR_*}`
prompt assembly, then the anthropic HTTP backend, which together let the LLM
coercion fallback (bd-ecb930) finally land.
