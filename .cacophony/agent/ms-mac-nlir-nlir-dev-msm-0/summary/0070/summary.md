# Session summary — retained cached LLM actions in the web workspace

## Goal

Complete bd-970e05's long-lived web surface by carrying the landed incremental cache across explicit WASM Run and streamed Step actions, while preserving the core safety rule that typing itself performs only free deterministic preview work.

## Bead(s)

- `bd-970e05` — Live partial-result display, slice 7 and final parent slice.
- Reflection follow-on: draft `bd-afe2ee` captures the separate Pi process-lifecycle/security design for a future persistent cached LLM worker; it is not part of this implementation.

## Before state

- Web typing already showed a debounced, non-persisting det result; explicit LLM Run/Step existed and Step streamed reductions.
- Every WASM export created a new `Evaluator`, so each explicit action discarded the cache and re-ran unchanged semantic subcalls.
- The workspace had no cache invalidation hook when config or external endpoint/key/model settings changed.
- The live-preview label mentioned only “Run for llm,” not the cached streamed Step path.

## After state

- The long-lived WASM module owns one thread-local cloneable `EvaluationCache`. LLM `evaluate`, batch `step`, and `stepStream` all use the cached core APIs, so Run and streamed Step reuse completed semantic calls across actions.
- New `clearEvaluationCache()` is exported to JavaScript. Workspace config apply/reset and endpoint, API-key, or model edits clear retained calls before changing policy.
- Context edits do not require blanket invalidation because rendered context-derived operands are part of each semantic call key and naturally invalidate dependent parents.
- Mock and real workspace adapters share the clear method; cache invalidation failures degrade as an optimisation miss rather than breaking UI state.
- The automatic line remains det-only/no-realiser and now labels the explicit boundary as “Run/Step for cached llm.” No paid call fires on edit.
- Pi's existing automatic det preview plus explicit `|send`/`/nlir` full evaluation satisfy the safe partial-display parent contract. Cross-process cached/streamed Pi LLM preview is deliberately separated into draft bd-afe2ee rather than persisting model outputs ad hoc.

## Diff summary

- Code/content commit: `bc042a4` (`bd-970e05` slice 7). Final landed squash SHA will come from the reintegration receipt.
- Summary artefact commit: intentionally omitted; this file must not self-reference its own mutable SHA.
- Files touched: `crates/nlir-wasm/src/lib.rs`, `site/workspace/workspace.js`, `docs/design/agent-vocabulary.md`.
- Tests: nlir-wasm host unit test for shared thread-local clones + explicit clear; wasm32-unknown-unknown cargo check; nlir-wasm all-target clippy with warnings denied; wasm formatter; JavaScript syntax; diff checks.
- Behavioural delta: repeated explicit web LLM actions now pay only for changed semantic subcalls, and changing any external realiser/config policy deterministically empties the cache.

## Operator-takeaway

The web workspace already had the right consent boundary—det on edit, LLM only on Run/Step. This slice makes that explicit tier affordable by keeping the Rust cache alive for the browser session and clearing it exactly when semantic policy changes; the parent can close without inventing unsafe disk persistence for Pi subprocesses.
