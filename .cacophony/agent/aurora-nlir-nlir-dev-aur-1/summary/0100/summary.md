# Session summary — golf #87 (negate early) + target #85 (simplification)

## What landed
- examples/golf-aur1-87-negateearly.sh — NEGATE EARLY: `>!x ≠ !>x`, a COUNTEREXAMPLE to #75's
  orthogonal→commute. `>!x` (negate the CLAIM, then develop) → a coherent case for the opposite
  ("microservices are wrong due to operational overhead"). `!>x` (develop the claim, then negate the
  ARGUMENT) → fluent but FALSE: it negates each true clause, so "microservices let you deploy
  independently / improve fault isolation" flips to "prevent independent deployment / worsen fault
  isolation" — inversions, not a counter-case. So `>` and `!` DON'T commute despite length⊥polarity —
  because `>` turns a claim into an ARGUMENT, and `!` means "the opposite" on a claim but "flip every
  clause" (→ falsehood) on an argument. Rule: negate EARLY (on the seed), never LATE (on the prose).
  Refines the commutativity theory: orthogonal axes commute ONLY when neither operator changes what
  the other operates on.
- examples/target-aur1-85-simplify.sh — 74th `?` framing: 'is there a simpler way to do this'? (36c)
  → "Is there a simpler way to do this?" simplify the EXISTING approach (vs #79 simplest-thing, #21
  best-way).

## Notes
- Paren-echo fix still HOLDING for Harry's green-light (msm0 +1'd).
