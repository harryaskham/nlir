# Session summary — explicit cached LLM preview in the TUI

## Goal

Use bd-970e05's newly-landed incremental cache and streaming APIs to finish the existing TUI child: provide a clear, explicitly paid LLM preview that never blocks the crossterm event loop, never persists speculative context, and never weakens automatic deterministic preview as the safe default.

## Bead(s)

- `bd-16d86c` — nlir TUI: opt-in LLM-mode evaluation in the workbench.
- `bd-970e05` — Live partial-result display parent, slice 6. Parent remains open for Pi/web opt-in LLM follow-ons.

## Before state

- Typing in `nlir tui` automatically produced a debounced det-only preview; Enter committed a det evaluation.
- The shared bounded `EvaluationCache` and cached async step stream had landed at `426d87d`, but no UI surface invoked them.
- Running an LLM evaluation on the TUI thread would freeze input/rendering, and there was no explicit cost gate or stale-result suppression.

## After state

- Ctrl-L is the sole explicit LLM-preview trigger in the Expression pane. Automatic typing preview remains det-only and free; Enter still commits det evaluation.
- One named worker thread evaluates an owned context clone through `step_trace_streaming_async_with_cache`, sending initial/completed reductions over an mpsc channel to the UI thread. The speculative context is never saved.
- The live Output pane updates as reductions arrive and the status line labels the call explicit/paid, running, complete, or errored. The event loop continues polling and rendering throughout.
- Only one paid preview runs at a time. Job id + source expression guards suppress late steps after edits; a new request waits for the active one rather than creating a call storm.
- One bounded cache survives repeated Ctrl-L runs for unchanged subcall reuse. Config is snapshotted for the TUI session; context values are re-opened per request.
- Initial help and empty Output copy now advertise Ctrl-L distinctly from det preview/commit.

## Diff summary

- Code/content commit: `c63a027` (`bd-16d86c`, `bd-970e05` slice 6). Final landed squash SHA will come from the reintegration receipt.
- Summary artefact commit: intentionally omitted; this file must not self-reference its own mutable SHA.
- Files touched: `src/main.rs`, `src/tui.rs`, `docs/design/agent-vocabulary.md`.
- Tests: 35/35 binary tests; 309/309 library tests; injected-realiser TUI streaming + second-run cache-hit test; stale job/edit suppression test; `cargo clippy --all-targets -- -D warnings`; rustfmt/diff checks; real pseudo-TTY smoke with a command-backed model visibly streamed `preview-ok` and exited cleanly.
- Behavioural delta: TUI users can request a paid semantic preview without committing or freezing the workbench, and unchanged LLM steps are free on subsequent Ctrl-L runs.

## Operator-takeaway

LLM preview is deliberately not “live on every key.” Det remains automatic; Ctrl-L is the visible consent boundary. Behind that key, the landed cache and step stream now work together on a background thread, so the TUI can paint partial semantic results without persistence, duplicate calls, stale overwrites, or UI blocking.
