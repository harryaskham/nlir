# Session summary — golf #17 (accumulator) + target #15 (disambiguation question)

## What landed
- examples/golf-aur1-17-accumulator.sh — `a;b;c;&;~$`: the stack as an inbox — push N
  separate items, nullary `&` folds the WHOLE stack into one, `~$` distils. Three quarterly
  metrics ("sales up 20%", "churn rose 5%", "NPS fell 3 points") → "Sales grew 20% this
  quarter, but churn rose 5% and NPS fell 3 points." Nullary & eats however many you pushed.
- examples/target-aur1-15-disambig.sh — `('a mutex'|'a semaphore')?` (26c) → "Is it a mutex
  or a semaphore?" | lists the options, ? reaches for the "is it X or Y?" identification
  frame (distinct from #08 should-I: two `|`-joined nouns steer ? to identification not decision).

## Operator-takeaway
The nullary fold makes the stack a variable-arity inbox: push any number of items, one `&`
collapses them all. And | ∘ ? gives an identification question, a fresh face vs should-I.
