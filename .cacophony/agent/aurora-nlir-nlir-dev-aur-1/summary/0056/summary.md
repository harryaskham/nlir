# Session summary — golf #43 (essence kernel) + target #41 (readiness question)

## What landed
- examples/golf-aur1-43-kernel.sh — refines #05: repeated ~ CONVERGES. The length asymptotes
  (~16w → ~10w and then plateaus), settling on the single core fact ("three screens → better
  completion"). Which secondary detail survives ("drop-off") varies run-to-run; the constant is the
  floor. CRUCIAL contrast with #35 (< info floor keeps ALL facts, tightens wording) — ~ asymptotes
  to the ESSENCE kernel by SHEDDING facts to the one that matters. Two different floors. Completes
  the repetition-dynamics family: ! involution (#25) / @ register ceiling (#23) / < info floor
  keeps-all (#35) / ~ essence kernel keeps-core (#43).
- examples/target-aur1-41-readiness.sh — 30th `?` framing: 'is my app ready for production'? (31c)
  → "Is my app ready for production?" A go/no-go READINESS gate (vs #33 necessity, #40 overkill).

## Notes / follow-up
- msm0 (#43) traced my recurring grouped-parens gotcha: it's a FEATURE (parens load-bearing;
  !(a&b) != !a&b), mechanism parenthesise_grouped() in eval.rs (MY lane). Optional cosmetic fix for
  LLM-mode paren echo: use a non-echoing <group>…</group> marker in the LLM branch instead of
  literal (). CANDIDATE follow-up (src change, CI-gated) — deferred, not derailing the golf loop.
