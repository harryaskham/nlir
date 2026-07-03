# Session summary — fix config.example.yaml command backends (bd-3fbf05)

## Goal

While dogfooding nlir in LLM mode (Harry's directive), make the shipped example
config actually work with the real claude + pi binaries and fix the bug that made
every command-model realisation fail.

## Bead(s)

- `bd-3fbf05` — config.example.yaml command models: YAML folded-scalar keeps
  newlines, breaking bash command backends (bug, found dogfooding)

## Before state

- Failing tests: none, but the shipped config was functionally broken in llm
  mode: `command:` used a `>` folded scalar with more-indented continuations,
  which YAML keeps as literal newlines, so `bash -c` ran each flag line
  separately (`--print: command not found`, exit 127).

## After state

- Failing tests: none. example_config_parses_and_validates green.
- Config works end-to-end in llm mode via the claude/pi binaries: verified
  `'apples'&'oranges'&'pears'` → "apples and oranges and pears" and a `~` summary.

## Diff summary

- Code/content commit: `8454414`.
- Files touched: `config.example.yaml` only.
- Behavioural delta: `command:` fields single-lined (echo's `command: |` literal
  block preserved); `sonnet`→claude-sonnet-5 (claude), `gpt-5.5`→`copilot`
  (github-copilot/claude-sonnet-4.6 via pi — fixes the `github_copilot` underscore
  and the non-existent copilot claude-sonnet-5); default operators/coercions/
  defaults.model repointed haiku→sonnet so it runs on the binaries alone (no
  ANTHROPIC_API_KEY); added the `summary` (~) operator; `haiku` kept as an
  illustrative direct-HTTP model.

## Operator-takeaway

Two latent config bugs surfaced immediately on the first real llm invocation: the
`>` folded-scalar-keeps-newlines gotcha (the deceptive one — it looks like it
folds to one line but doesn't for indented continuations) and the `github_copilot`
(underscore) provider prefix pi rejects (it wants `github-copilot`). Both were in
the shipped example, so anyone copying it would have hit a broken command backend.
The fix also turns the example into a working out-of-the-box config on any machine
with the claude/pi CLIs. This is the first of the dogfooding loop; more operator
coverage and cases follow.
