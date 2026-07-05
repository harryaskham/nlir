# Session summary — Front-page hero: trivial 2*21 → programmable-nlir flagship

## Goal

Harry: "make the front page example more complex — currently just 2*21, not much
of a hero element." Replace the trivial arithmetic hero with something that
showcases nlir's power while still running live in the browser with no key.

## Bead(s)

- `bd-af5638` — Front-page hero: replace trivial 2*21 with a programmable-nlir
  example (fold∘map sum-of-squares).

## Before state

- `site/hero-live.html` (the live in-browser evaluator, det mode / no key, with
  Run + Step buttons) defaulted its input to `2 * 21` → 42 — trivial arithmetic
  that reads as a calculator, not a language.

## After state

- Hero input now defaults to `$fold%({$0+$1},$map%({$0*$0},[1,2,3]))` → 14
  (sum of squares via fold∘map): deterministic (runs live, no key), and it
  showcases the just-shipped programmable core — forms `{$0*$0}`, higher-order
  `$map`/`$fold`, and composition. A real one-line PROGRAM, not a calculator.
- Hero-note enriched to explain it ("map a squaring form over a list, then fold
  to add them; press Step to watch it reduce") while keeping the LLM-workspace
  pointer to `@'lmk if any Qs'`.
- Verified in det mode with config.example.yaml (native lib == wasm lib): →14,
  and `nlir step` shows the reduction unfolding.

## Diff summary

- Code/content commits: pending final squash SHA from the reintegration receipt.
- Files touched: `site/hero-live.html` — hero input default value + hero-note.
- Tests: none (static site content; the example is verified via the shared lib
  in det mode). Behavioural delta: front-page live demo now runs a composed
  program instead of `2 * 21`.

## Operator-takeaway

The homepage now leads with nlir as a *programmable language* — "sum of squares
in one line of sigils, running live in your browser, no key" — instead of a
2×21 calculator. It rides the forms/map/fold work that shipped this session, and
the Step button lets a visitor watch the composition reduce. Deterministic so it
needs no key; the LLM side is still one click away in the workspace.
