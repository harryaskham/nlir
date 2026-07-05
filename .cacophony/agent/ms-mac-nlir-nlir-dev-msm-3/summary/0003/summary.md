# Session summary — REPL :step live-render leg of step-streaming (bd-89eb89)

## Goal

Deliver the REPL interactive-stepper leg of the cross-cutting "stream each eval
step live, not batch at the end" feature. The `:step` stepper already renders
each step live when the user Tab-drives it, but its Enter / run-to-completion
path silently drained to the final value — so in llm mode you'd stare at a frozen
prompt through every slow realisation, then see only the answer. Make
run-to-completion stream each reduction as it resolves, preserving the
interactive Tab model.

## Bead(s)

- `bd-89eb89` — stream each eval step live (cross-cutting). My leg: REPL `:step` /
  `run_step_view` interactive live-render. (Other legs: `nlir step` CLI = msm-1,
  TUI Ctrl-T = msm-2, wasm = aurora, eval-core streaming API = msm-0 @a7085e2.)

## Before state

- `run_step_view` (src/main.rs) drives `Evaluator::step_once` per keypress. Tab
  path renders each step live; the `StepKey::Run` (Enter) branch looped
  `step_once` to `Step::Done` WITHOUT rendering intermediates — only the final
  value printed after raw-mode exit.
- Tests: 259 lib green pre-change (msm-0's streaming API had just landed).

## After state

- The `StepKey::Run` branch now renders + flushes `cur.render_step()` after each
  `Step::Reduced`, so run-to-completion streams the whole reduction path live.
  Verified on a real pty via tmux-cli: `:step (1+2)*(3+4)` + Enter streams
  `(1 + 2) * (3 + 4)` → `«3» * (3 + 4)` → `«3» * «7»` → `«21»` → `21`
  (previously only `21` appeared).
- Interactive Tab/Enter/cancel controls, the persistent single-`Evaluator`
  (stack + realise cache + `key=RHS` writes), and the non-TTY single-eval
  degrade are all unchanged.
- Tests: fmt + clippy -D warnings clean; native build clean.

## Diff summary

- Code/content commits: pending final squash SHA from the reintegration receipt.
- Summary artefact commit: intentionally omitted (no self-reference).
- Files touched: `src/main.rs` — `run_step_view` `StepKey::Run` branch renders
  each intermediate step during run-to-completion.
- Design note: this leg deliberately does NOT use msm-0's `step_trace_streaming`.
  That API drives a fresh evaluation from the expr STRING; the interactive stepper
  must CONTINUE from the current partially-reduced `cur` on the same `Evaluator`,
  so calling `step_trace_streaming` mid-way would restart evaluation and re-run
  already-resolved llm realisations. The correct fix is to render each
  `step_once` result in the existing drive loop.
- Tests: +0 (interactive TTY path; validated manually via tmux-cli on a real pty;
  non-TTY behaviour unchanged so scripted tests are unaffected).

## Operator-takeaway

Pressing Enter in the REPL step-through now shows the expression reducing live
step by step, not just the final answer — which is exactly where it pays off in
llm mode (each reduction appears as its realisation resolves instead of a frozen
wait). Native-only, interactive-TTY behaviour; the plain `nlir step`, TUI, and
wasm legs of bd-89eb89 are owned by msm-1/msm-2/aurora against the same
msm-0 streaming core, so the bead stays open until those land.
