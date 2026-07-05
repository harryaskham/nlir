# Session summary — TUI live det preview (bd-970e05 slice 1)

## Goal

First slice of Harry's live partial result display (bd-970e05): a deterministic
debounced preview in the `nlir tui` workbench — as you type an expression, the
Output pane shows the result-so-far ~350ms after you stop typing, no Enter
needed. Lane split with msm-0 (confirmed): I own the TUI det preview against the
existing `evaluate`; msm-0 owns the incremental-cache eval-core for the llm tier;
aur-1 (web) / msm-3 (REPL) own their surfaces.

## Bead(s)

- `bd-970e05` — Live partial result display (cross-surface feature, P2). This is
  the TUI det slice; the bead stays open for the REPL/web/Pi + llm-cache tiers.

## Before state

- The workbench evaluated only on Enter; nothing until you submitted.
- The event loop blocked on `event::read()` (no timer wakeups).
- Bin tests: 31.

## After state

- The run_tui loop now polls (`event::poll(120ms)`) instead of blocking, so it
  wakes to service a debounce timer. It tracks the expr buffer + when it last
  changed; ~350ms after the last keystroke it det-evaluates the current buffer
  (NON-persisting) and sets a live preview.
- The Output pane shows the live preview italic-cyan under an "Output · live"
  title (speculative/uncommitted), falling back to the committed result (or the
  placeholder) otherwise. A mid-edit parse error / non-det expr → no preview
  (rather than a flickering error). Enter commits (persists + shows normally) and
  clears the preview.
- `evaluate` runs in `Mode::Det`, so the preview is instant, offline, and free —
  no cost gating needed for this tier (the llm tier + incremental cache is msm-0's).
- Bin tests: 31 (loop/preview validated via pty smoke; pure Workbench logic
  unchanged).

## Diff summary

- Code/content commits: pending final squash SHA from the reintegration receipt.
- Files: `src/tui.rs` (Workbench `preview` field + `set_preview`/`expr_buffer`;
  preview-aware `render_output`), `src/main.rs` (poll+debounce event loop,
  Enter-clears-preview, `tui_eval_preview` non-persisting det helper).
- Tests: 31 bin. Validation: `cargo test` (262 lib + 31 bin), `cargo clippy
  --all-targets -D warnings`, `cargo fmt --check`, and a real-pty smoke — typing
  `2+3*4` (no Enter) showed `14` live in the Output pane.

## Operator-takeaway

The workbench now previews as you think: type an expression and the result
appears a beat after you pause, in italic to mark it speculative, committing only
on Enter. It's deterministic-only for now (instant + free), which is the safe,
no-cost tier. The llm-mode live preview (with msm-0's incremental subexpression
cache so a small edit only re-fires the edited llm node) is the next tier, and
the REPL / web / Pi surfaces are their owners' slices under the same bead.
