# Session summary — golf #114 (the bookends / stack bi-indexing) + target #112 (experiment)

## What landed
- examples/golf-aur1-114-bookends.sh — THE BOOKENDS: the nlir stack is BI-INDEXED (verified this tick,
  correcting my own wrong assumption): `$0/$1/$2…` count from the BOTTOM (chronological, $0 = FIRST
  pushed); `$/$-1/$-2…` count from the TOP (recency, $ = $-1 = LATEST, $-2 = one before) — exactly
  like `^` message indices (^_0 first-user … ^_-1 last-user). So `~($0 & $)` distils the BOOKENDS of a
  discussion: where it STARTED ($0) and where it is NOW ($). Push three evolving positions (in-house
  → vendor → open-source) → ~($0 & $) = "The team debated whether to build in-house or use an
  open-source library" (both poles). Honest note: `~` relates the two poles, doesn't show DIRECTION
  (A→B) — that wants the directional CONTRAST/DIFF `Δ` op I proposed; ~(a&b) is order-blind.
  KEY REFERENCE: stack index convention — $=$-1=top; $-2=below-top; positive $N from bottom ($0=first).
- examples/target-aur1-112-experiment.sh — 101st `?` framing: 'whats the smallest experiment'? (31c)
  → "What's the smallest experiment?" the cheapest TEST that validates before committing (vs #79
  minimalism, #69 first-step).

## Notes
- Harry trains/lambda consolidated; aur-0 live-dogfood held. Operator spec + paren-echo fix queued.
