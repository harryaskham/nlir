# Session summary — golf #29 (synthesis law) + target #27 (worth-it question)

## What landed
- examples/golf-aur1-29-synthesis.sh — `~(a&b) ≠ ~a&~b`: summary does NOT distribute over &.
  ~(a&b) SYNTHESIZES — sees both operands at once and finds the RELATIONSHIP ("cut latency AT
  THE COST OF 2GB overhead" = a tradeoff link); ~a&~b ENUMERATES — two summaries joined with
  "and", no link. Contrast with #27 (@ DOES distribute, pointwise). So distributivity-over-&
  reveals an operator's character: @ pointwise, ~ synthesising. This is exactly WHY merge (#15)
  and diff (#16) use ~(a&b) — the cross-operand synthesis is the feature.
- examples/target-aur1-27-worthit.sh — 16th `?` framing: 'react worth learning in 2026'? (30c) →
  "Is React worth learning in 2026?" A VALUE judgement (vs #08 "Should I…?" decision).

## Operator-takeaway
Whether an op distributes over & tells you if it's pointwise (@) or synthesising (~). Reach for
the grouped ~(a&b) when you want the RELATIONSHIP between things, not a list of them.
