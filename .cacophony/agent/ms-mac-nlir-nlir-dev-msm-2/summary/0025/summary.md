# Session summary — revert gauss card (det-math is substrate, not nlir's differentiator)

## Goal

Course-correct the "why nlir, not a prompt?" showcase after Harry's critique:
"how do these showcase nlir, instead of just functional/array programming?"

## Bead(s)

- `bd-640ff9` — revert the gauss card (pure det-math showcases array programming).
- (reverts my earlier `bd-7d03e1` gauss card.)

## Before state

- The "why nlir" set included the `gauss` card (`{$0+$1}⊘(1..100)`→5050) — pure
  deterministic arithmetic, the only exact-gated card. Harry (rightly) noted this
  is just array programming (J/APL/numpy do `fold(+,1..100)`); "exact arithmetic"
  argues for "a real language," not "nlir." Unanimous team convergence
  (msm-0/aur-0/aur-1/msm-3/aur-2 all +1 on pulling it).

## After state

- Removed the `gauss` card from build-showcase.py, its README block, and the PNG.
- The "why nlir" set is now focused purely on the semantic/FUSION layer — the
  actual differentiator: exact structure over fuzzy/semantic operands (predicate
  or data is MEANING), which no array language has and no prompt does reliably.
  Those beats remain carded: semantic-access, fuzzy-sum (extract numbers from
  language + exact sum), fuzzy-count (semantic ~> predicate + exact count),
  fuzzy-decide, map-lang, generation, self-judge, reusable-parts, self-verify.
- Det-math stays as substrate in msm-1's runnable gallery, not a headline.
- Guardrail honored (msm-3/aur-2): fusion cards stay live-caption (the semantic
  half is model-dependent), never hard-asserted; self-verify makes fuzzy
  trustworthy.
- verify-showcase --det-only green (3 exact-verified, 0 failed).

## Diff summary

- Commit: `cd0d66d` (`bd-640ff9`); final squash SHA from receipt.
- Files: build-showcase.py (-gauss card), README.md (-gauss block),
  showcase/nlir-gauss.png (deleted). 12 deletions.
- Tests: verify-showcase --det-only 3 exact / 8 ran / 0 failed.

## Operator-takeaway

Harry's sharp critique corrected a real drift: the mathy round filled genuine
language gaps (range/$len/$gt/$sqrt/$mod) but the det-math tiles showcased nlir's
substrate (array programming), not its differentiator. Pulling Gauss refocuses the
narrative set on the fusion of exact structure with semantic meaning — the one
thing neither a prompt (unreliable) nor numpy (no understanding) can do. The
det-math lives on as substrate in the runnable gallery. Intellectual-honesty
course-correction, unanimously endorsed.
