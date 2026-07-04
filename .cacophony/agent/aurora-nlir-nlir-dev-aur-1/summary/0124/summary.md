# Session summary — golf #111 (register⊥polarity commute) + target #109 (exit)

## What landed
- examples/golf-aur1-111-registerpolarity.sh — REGISTER ⊥ POLARITY COMMUTE (and why > was the
  exception): `@!x ≈ !@x` — formalise-the-negation and negate-the-formal both land as a formal
  negative (same register + polarity; wording varies). CONTRAST >!x ≠ !>x (#87): those diverge
  (measured doubt vs utter failure). WHY: `@` is a PURE register move (the claim stays a claim) so
  `!` negates the same thing either way → commute; `>` is TYPE-CHANGING (claim→argument), and
  negating a claim ≠ negating an argument → order matters. This RESOLVES #87's puzzle: the
  commutativity map is complete — register⊥length (#75/#98) and register⊥polarity (here) commute
  because @ never changes an operand's TYPE; the ONLY orthogonal pair that fails involves > (#87),
  precisely because > does. Rule: reorder freely around @; never reorder ! across >.
- examples/target-aur1-109-exit.sh — 98th `?` framing: 'whats the exit strategy'? (26c) → "What's the
  exit strategy?" the planned OFF-RAMP / wind-down before committing (vs #84 reversibility, #35
  contingency).

## Notes
- Harry trains/lambda consolidated; aur-0 live-dogfood held to fold if Harry follows up. Operator
  spec + paren-echo fix queued for Harry's green-light.
