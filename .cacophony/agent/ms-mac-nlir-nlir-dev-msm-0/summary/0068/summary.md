# Session summary — incremental cache core for live LLM previews

## Goal

Deliver the expensive core behind bd-970e05's remaining opt-in LLM-preview tier: reuse unchanged semantic subcalls across debounced edits, invalidate only changed/dependent calls by key, and make the same retained cache available to batch evaluation and partial-result streaming without changing the already-landed det-preview safety defaults.

## Bead(s)

- `bd-970e05` — Live partial-result display across REPL/TUI/Pi/web; this session implements slice 5, the shared incremental LLM cache core. The cross-surface tracker remains open for opt-in UI wiring.

## Before state

- TUI, Pi plugin, REPL, and web deterministic previews were already landed and safe/free by default.
- `Evaluator` memoised repeated realisations only inside one run. Every new debounced async evaluation created an empty cache and re-fired all LLM calls, even for unchanged sibling subtrees.
- Async evaluation intentionally bypassed the sync cache, and cached evaluation could not be combined with the existing streaming step API.
- The design still called for a separate AST-diff invalidation pass even though semantic call inputs already encode the dependency boundary.

## After state

- Public cloneable `EvaluationCache` can be retained across sync or async runs. Default APIs keep run-local behaviour; `evaluate_with_cache` and `evaluate_async_with_cache` opt into cross-run reuse.
- Async realisation now uses the same semantic key as sync—op, mode, model, grouping, rendered operands, and seed—without holding the cache mutex across a realiser await.
- `step_async_with_cache` and `step_trace_streaming_async_with_cache` combine retained call reuse with partial-result delivery.
- Edit-local regression: alpha/beta costs two calls; changing only beta→gamma costs one additional call; reverting is all cache hits. `_cache=false` forces fresh calls.
- Retention is bounded to 1024 completed realisations, with explicit `clear()` for config/model-policy changes.
- SPEC and the vocabulary design now document key-driven dependent invalidation: changed child output changes parent operands, so no separate AST-diff pass is required.

## Diff summary

- Code/content commit: `8179774` (`bd-970e05` slice 5). Final landed squash SHA will come from the reintegration receipt.
- Summary artefact commit: intentionally omitted; this file must not self-reference its own mutable SHA.
- Files touched: `src/eval.rs`, `SPEC.md`, `docs/design/agent-vocabulary.md`.
- Tests: 309/309 library tests; focused sync/async cross-run cache tests; cached streaming trace test; `_cache=false` bypass; 1024-entry bound; `cargo clippy --lib -- -D warnings`; rustfmt and diff checks.
- Behavioural delta: an opted-in live LLM editor can now debounce repeatedly without paying again for unchanged semantic subtrees, while existing callers remain run-local and deterministic previews remain the default.

## Operator-takeaway

The dependency graph did not need a second diff engine: the realised operand values are already the dependency fingerprint. Retaining those semantic call keys across edits gives targeted invalidation naturally, and the same cache now feeds both final values and incremental step streams; only explicit opt-in surface wiring remains.
