# Session summary — golf #26 (non-commutativity law) + target #24 (diplomatic pushback)

## What landed
- examples/golf-aur1-26-noncommute.sh — `@:x ≠ :@x`: composition does NOT commute — same two
  register ops, opposite registers, because the OUTERMOST (last-applied) op wins. @:x ends
  FORMAL (last @), :@x ends SIMPLE (last :). Inner op = starting point, outer op = destination.
  Adds to the operator-algebra series: ! involution (#25) / @ saturation (#23) / ~ intensification
  (#05) / composition non-commutativity (#26).
- examples/target-aur1-24-pushback.sh — `@!'skip code review before merging'` (33c) → "Code
  review must not be skipped/omitted prior to merging." @∘!: ! rejects the proposal, @ makes the
  refusal diplomatic — a real review-comment pushback from a terse seed.

## Operator-takeaway
Order matters (non-commutativity) — the last register op sets the final register. Together with
the repetition laws, nlir has a small but real operator algebra worth reasoning about.
