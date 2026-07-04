# Session summary — golf #77 (bind before you build) + target #75 (shared-experience)

## What landed
- examples/golf-aur1-77-bind.sh — BIND BEFORE YOU BUILD: `>[a,b]` (list) expands only the LAST point
  (drops the rest — "we need faster CI…" with test-coverage vanished), while `>(a&b)` (join) BINDS
  both and weaves them into one argument. The `&` binds a and b into ONE operand so a unary op like
  > acts on the whole pair; a list `[a,b]` leaves them as separate operands and > latches onto the
  last. So the rule for building on multiple points: JOIN them (`&`), don't list them. Explains #71's
  design choice (the weave uses & not []). (Join output carries the cosmetic leading `(` = paren-echo.)
- examples/target-aur1-75-sharedexp.sh — 64th `?` framing: 'is it just me or is this confusing'? (37c)
  → "Is it just me, or is this confusing?" (? even adds the natural comma) — is the reaction SHARED
  (vs #66 overthinking, #45 is-it-normal).

## Notes
- Paren-echo fix still HOLDING for Harry's green-light (msm0 +1'd; visible again in >(a&b) here).
