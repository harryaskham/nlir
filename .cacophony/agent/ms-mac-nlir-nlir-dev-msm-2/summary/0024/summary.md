# Session summary — gauss flagship card (first exact-gated mathy card)

## Goal

Turn the mathy-golf round's honest verdict into a shipped card: the first
EXACT-gated card in the "why nlir, not a prompt?" set — a value a prompt
genuinely can't compute — unlocked by aur-1's numeric-range op.

## Bead(s)

- `bd-7d03e1` — showcase: `gauss` flagship card (sum 1..100 → 5050).
- (context) built on aur-1's `bd-791410` numeric range op (c790621).

## Before state

- Harry redirected to "creative golf + interesting mathy use cases." The round
  established the honest tiering: semantic-access math (`'primes'..N`) is
  transport-FLAKY (msm-3: 11,7,7 over 3 runs) → unsafe to assert; recall is fame;
  DET-MATH is the only terse+computed+assertable tier.
- Every existing showcase card was llm live-caption; none was exact-gated.
- I ran a rigorous +0 card audit (reverted a fragile/duplicate math-by-meaning
  card) and queued the Gauss card pending aur-1's range op.

## After state

- `gauss` card: `{$0+$1}⊘(1..100)` → "5050" — Gauss sum, 100 terms of exact
  arithmetic folded over a range literal, ZERO model. pill "det · exact · a
  prompt can't".
- The FIRST exact-gated card in the set: verify-showcase --det-only now shows
  "✓ EXACT gauss det → '5050'" (4 exact-verified, 0 failed). aur-1's
  numeric-range-gauss det-suite test (config.example.yaml:725) locks 5050 in CI.
- README "Why nlir" block: the exact-arithmetic-a-prompt-can't entry.

## Diff summary

- Commit: `48506c2` (`bd-7d03e1`); final squash SHA from receipt.
- Files: `scripts/build-showcase.py` (+1 card), `README.md` (+gauss block),
  `showcase/nlir-gauss.png` (new).
- Tests: verify-showcase --det-only 4 exact-verified / 8 ran-non-empty / 0 failed;
  CI-gated by aur-1's det-suite numeric-range-gauss case.
- Behavioural delta: the set now has a hard-asserted mathy flagship.

## Embedded artefacts

- `showcase/nlir-gauss.png` — sum 1..100 = 5050, model-free, exact.

## Operator-takeaway

Harry's mathy-golf redirect produced great science (the reproducibility/robustness
tiering) and now a durable flagship card: the first exact-gated "why nlir, not a
prompt" beat where a prompt is genuinely unreliable (100-term arithmetic) and
nlir is deterministic. Team-built: aur-1 (range op + CI gate), aur-0/aur-2
(fold-fusion + live-verify), msm-0/msm-1/msm-3 (golf + reliability policy).
