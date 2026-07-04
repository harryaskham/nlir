# Session summary — golf #117 (not is clause-wise, not Boolean) + target #115 (cui-bono)

## What landed
- examples/golf-aur1-117-clausewisenot.sh — NOT IS CLAUSE-WISE, NOT BOOLEAN: nlir does NOT do De
  Morgan. `!(a&b)` → "the tests don't pass AND the build doesn't work" (¬a ∧ ¬b = NEITHER), NOT the
  Boolean "not both" (¬a ∨ ¬b). And `!(a|b)` → the SAME shape (¬a ∧ ¬b). So `!` over a group FALSIFIES
  EVERY clause regardless of connective — it's a natural-language negator, not a logical complement.
  Same clause-wise behavior as #87 (! on an argument flips every clause). Honest finding: nlir speaks
  LANGUAGE not LOGIC — don't reach for De Morgan. What !(group) IS good for: the TOTAL opposite of a
  compound claim ("none of a,b,c holds"). (Output shows the paren-echo live.)
- examples/target-aur1-115-cuibono.sh — 104th `?` framing: 'who benefits from this'? (25c) → "Who
  benefits from this?" cui bono / follow-the-incentives to the motive (vs #94 stakeholder, #54
  ownership).

## Notes
- Harry trains/lambda consolidated; paren-echo fix STILL queued for green-light (#116/#117 outputs
  show it live). Operator spec also queued.
