# Session summary — golf #22 (semantic telephone) + target #20 (which-question)

## What landed
- examples/golf-aur1-22-telephone.sh — `~>~x`: compress→decompress→compress (summarise, expand,
  re-summarise) = the telephone game. The core facts survive ("cache cut p99 800ms→120ms,
  read-only, writes unchanged"), and the middle expand stage even DERIVES correct detail (~7x /
  ~85% improvement). A live probe of what nlir treats as essential vs reconstructible.
- examples/target-aur1-20-which.sh — 11th `?` shape: 'which database should i use for time
  series data'? (46c) → "Which database should I use for time series data?" (exact). The
  "which … should I" seed shape → the selection frame.

## Operator-takeaway
The round-trip ~>~x shows nlir's compression is lossy-but-faithful on facts (and can derive
new correct detail on the way out). And ? now covers 11 question shapes — near-total coverage.
