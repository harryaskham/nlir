# Session summary — LLM percent operand substitution (bd-a47a02)

## Goal

Add the `%` placeholder fill for LLM prompt templates: turn the `%` in an
operator's (or coercion's) `prompt:` into the operand text wrapped in `<text>`
tags, so the assembled prompt carries the operands in the shape the model
instructions expect. Pure string logic — the smallest, most reusable piece of
the prompt pipeline.

## Bead(s)

- `bd-a47a02` — LLM: percent operand substitution
- parent: `bd-b71b0b` — LLM epic (label `llm`)
- same module `src/llm.rs`

## Before state

- Failing tests: none. `src/llm.rs` had model resolution, result extraction, and
  the command backend, but nothing filled a prompt template's `%`.
- 110 lib tests green.

## After state

- Failing tests: none. 124 lib tests green (`cargo test --lib`), fmt/clippy clean.
- `llm::substitute_operands(template, operands) -> String`.

## Diff summary

- Code/content commit: `ba2c9ed` (final landed squash SHA from the reintegration
  receipt).
- Files touched: `src/llm.rs` only (`substitute_operands` + `operand_block` +
  6 tests).
- Tests: +6 (`%%` literal; single `<text>` tag; indexed `<text n=k>` variadic;
  empty operands; mixed `%%`/multiple `%`; verbatim operand insertion).
- Behavioural delta: `%%` → `%`; a lone `%` → `<text>OP</text>` for one operand,
  newline-joined `<text n=k>OP_k</text>` for many, empty for none. Every lone `%`
  expands to the same block; operands are inserted verbatim (no XML escaping).

## Operator-takeaway

The one under-specified point the SPEC left open was how multiple operands render
inside `%`: I used newline-joined `<text n=0>…</text><text n=1>…</text>` indexed
blocks (single operand stays the bare `<text>…</text>`), which matches the
`arity-1 vs variadic` split in the bead and is self-delimiting for the model.
Operands are inserted verbatim — the `system` prompt fragment already tells the
model to ignore the `<text>` tags, so escaping would only add noise. Next: the
`${NLIR_*}` prompt assembly (bd-e9983b) that stitches fragments + this filled
prompt into the final `NLIR_PROMPT`, then the anthropic backend and the LLM
coercion fallback.
