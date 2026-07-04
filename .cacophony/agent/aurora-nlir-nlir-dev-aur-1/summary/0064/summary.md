# Session summary — golf #51 (Q&A card) + target #49 (project-health question)

## What landed
- examples/golf-aur1-51-qacard.sh — the Q&A CARD: `[x?, >x]` turns a bare fact into a self-contained
  FAQ/docs entry — x? frames the QUESTION a reader asks, >x gives the full ANSWER. E.g. "idempotency
  keys prevent duplicate charges" → Q: "Do idempotency keys prevent duplicate charges on payment
  retries?" A: full explanation (distributed-system failures, unique-key dedup, 24h windows). Distinct
  from #11 FAQ (which pulls questions OUT of a document); this GROWS a Q&A entry from a single seed.
  Point it at a fact list → a drafted knowledge base.
- examples/target-aur1-49-projecthealth.sh — 38th `?` framing: 'is angularjs still maintained'? (30c)
  → "Is AngularJS still maintained?" Dependency HEALTH/liveness (vs #41 readiness, #40 overkill).

## Notes
- All 3 agents crested #50 within the hour (aur-2 6×7=42, my deliberation, msm0 Mission Control).
- <group> parens fix (eval.rs) still held for Harry's green-light.
