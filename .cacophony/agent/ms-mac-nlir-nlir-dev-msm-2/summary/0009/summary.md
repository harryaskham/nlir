# Session summary — Pi-plugin live det preview (bd-970e05 slice 2) + vocab-doc partial-display section

## Goal

Second surface of Harry's live partial result display (bd-970e05): a live
deterministic preview in the pi plugin editor — as you type a `|`-prefixed nlir
line, the det result-so-far appears above the editor, so you iterate on a chain
of thought before sending. Plus my assigned partial-result-display section (§4)
in the team's shared `docs/design/agent-vocabulary.md`.

## Bead(s)

- `bd-970e05` — Live partial result display (cross-surface). Slice 1 (TUI det
  preview) landed earlier @e38868b; this is slice 2 (pi plugin) + the vocab-doc
  UX section. Bead stays open for the llm-cache tier (msm-0) + REPL/web surfaces.

## Before state

- The pi extension (`extensions/nlir.js`) only expanded on send (`|expr` → English)
  and previewed via `/nlir EXPR`; the yellow nlir-mode editor tint existed but
  showed no result as you typed.
- agent-vocabulary.md §4 outlined the pi plugin as "the place to close this".

## After state

- The `NlirModeEditor.render()` hook (the only per-keystroke signal) now
  (re)schedules a ~350ms debounce when the `|`-buffer actually changes (guarded
  against per-frame re-renders), then det-evaluates via `nlir -e … --mode det`
  (offline, free — no llm calls) and shows the result-so-far in a `setWidget`
  `nlir »` widget above the editor. Cleared on leaving nlir mode or on send.
  Degrades silently if `setWidget`/`CustomEditor` are absent (the `|` expansion
  still works). `node --check` clean.
- agent-vocabulary.md §4 rewritten: both TUI + pi previews marked landed, plus a
  new "shared partial-display contract" (debounce not per-keystroke; det = safe
  free default; speculative ≠ committed; llm tier gated + cached on msm-0's
  incremental cache). §5 shortlist note updated.

## Diff summary

- Code/content commits: pending final squash SHA from the reintegration receipt.
- Files: `extensions/nlir.js` (preview constants + `setPreviewWidget`/
  `clearPreview`/`schedulePreview`; `render()` drives the debounced preview;
  clear-on-send), `docs/design/agent-vocabulary.md` (§4 partial-display section
  + §5 note).
- Tests: no Rust change (extension is JS + a design doc), so 262 lib + 31 bin
  unchanged. Gate: `node --check` on the extension; `--mode det` verified
  (`2+3*4` → `14`, offline). Interactive pi-plugin verification needs a pi
  session reload (same as the yellow-editor slice).

## Operator-takeaway

The pi plugin now previews as you think: type a `|`-prefixed nlir line and the
deterministic result appears above the prompt a beat after you pause, so you can
tune a chain of thought without sending it — the surface Harry specifically
asked for. It's det-only (instant/free); the llm-chain preview rides msm-0's
incremental cache so re-firing only the edited node keeps it affordable. Needs a
pi session reload to see it live.
