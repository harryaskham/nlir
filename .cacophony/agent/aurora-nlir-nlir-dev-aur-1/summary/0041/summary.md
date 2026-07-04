# Session summary — golf #28 (non-invertible pair) + target #26 (difference question)

## What landed
- examples/golf-aur1-28-roundtrip.sh — honest NEGATIVE result: `<>x ≠ x`. I hypothesized expand-
  then-shorten would round-trip to the seed; it DOESN'T — a 10-word sentence → ~130 words (>x) →
  ~75 words (<>x), still ~7x the original. `<`/`>` are RELATIVE length nudges (each adjusts vs
  ITS input), so there's no absolute anchor to return to → no fixpoint, no inverse. Completes an
  operator taxonomy: ! INVERTIBLE (involution #25) / @ ABSOLUTE fixpoint (saturation #23) / <,>
  RELATIVE (no fixpoint, #28). Knowing a pair does NOT invert is as useful as knowing one does.
- examples/target-aur1-26-difference.sh — 15th `?` framing: 'difference between tcp and udp'? (32c)
  → "What is the difference between TCP and UDP?" A two-subject CONTRAST question (vs #02 "What is
  X?" definition, #20 "Which X?" selection).

## Operator-takeaway
Operators split into three dynamic classes: invertible (!), absolutely-convergent (@ formal, ~
essence), and relative-non-convergent (<, >). Don't reach for <> expecting your original back.
