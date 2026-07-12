# Session summary — honest compression + typable configured map

## Goal

Recover the interrupted honest-golf proof, turn the team's measurements into a runnable and site-visible explanation that does not mistake model recall for compression, and incorporate Harry's live follow-up that structural map needs a keyboard-typable, config-owned spelling.

## Bead(s)

- `bd-6a7359` — Unmemorised golf round: honest compression ratio on novel targets.
- `bd-80e76f` — Add typable `<$>` map alias alongside `↦`.

## Before state

- `bd-6a7359` survived an earlier explicit stop only as an unclaimed WIP script commit; there was no honest-ratio README section or site card.
- The public examples still presented famous-target self-judging next to compression-oriented material without clearly separating recall, derivation, novel facts, and instruction-density.
- Map had the word builtin `$map%` and Unicode alias `↦`, but no keyboard-typable infix alias.
- `$`-leading configured punctuation operators were rejected even when they could not collide with `$name`, `$_key`, `$N`, `$-N`, or bare `$`.
- Headless Chrome could write a complete showcase PNG and then hang indefinitely during allocator teardown.

## After state

- `examples/move-msm0-honest-golf.sh` computes the honest 74-byte/9-byte = 8.2× instruction-density ratio offline, applies it to live novel input when a model is available, and uses semantic `~>` fact-survival rather than formatting-sensitive literal grep.
- `showcase/nlir-honest-ratio.png`, README, and the msm0 catalog now distinguish recall (reject the ratio), derivation (~7–10× with fact-survival), novel dense facts (~1×), and instruction-density (8.2×, zero recall).
- `config.example.yaml` declares `<$>` and `↦` as two ordinary operators with the same `builtin: map`; no map spelling is hardcoded in the evaluator.
- Generic longest-match now permits configured punctuation operators such as `$>` and `$(` while preserving all real stack/context dollar reads. Existing train syntax remains unchanged.
- Showcase capture detects a stable completed PNG and terminates Chrome's isolated process group, so a post-write browser hang no longer strands the renderer.
- Failing validation: none. One live two-item LLM translation run exceeded 180 seconds without partial output; det execution and LLM dry-run passed, and the evidence was routed to existing partial-progress bead `bd-970e05` rather than duplicated.

## Diff summary

- Code/content commits: `cb0138c` (recovered WIP proof), `c5ae715` (`bd-80e76f`), `f0e5202` (`bd-6a7359`). Final landed squash SHA will come from the reintegration receipt.
- Summary artefact commit: intentionally omitted; this file must not self-reference its own mutable SHA.
- Main touched surfaces: `config.example.yaml`, lexer/config/eval regression tests, CLI help, `SPEC.md`, README/cookbook/phrasebook/catalog, runnable pipe and honest-golf examples, showcase builder, and four regenerated/new PNG cards.
- Tests: targeted lexer/config/eval/train unit tests all passed; `nlir test --mode det` passed 187/187; det showcase verification reported 0 failures; debug binary build, rustfmt, shell syntax, Python compilation, keyless honest-ratio proof, three LLM dry-runs, and diff checks passed.
- Behavioural delta: users can write `form <$> list` everywhere the visual `form ↦ list` worked, including stdin line maps; the site now headlines compression of reusable instructions over supplied context rather than memorised prose.

## Operator-takeaway

The honest nlir compression claim is not “a tiny key retrieves a famous paragraph.” It is that a reusable 9-byte transform replaces a 74-byte instruction over live input, with semantic checks keeping novel facts honest; `<$>` makes the corresponding structural map usable from an ordinary keyboard without moving its meaning into Rust.
