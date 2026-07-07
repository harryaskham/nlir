# Session summary — golf→site: fuzzy-count + fuzzy-decide cards (round out the set)

## Goal

Continue the golf→site card pipeline: card the two referee-confirmed "why nlir"
shapes both lane owners explicitly pulled to me, rounding out the set's
categories (access · generation · pipe · decision) and updating the README.

## Bead(s)

- `bd-e097c1` — showcase: fuzzy-count (#2) + fuzzy-decide cards.
- (this session's earlier cards, landed: bd-e84379, bd-2b9354, bd-f2c97b,
  bd-b31517.)

## Before state

- The "why nlir" set had semantic/structural access + the fuzzy-sum pipe, but no
  fuzzy-FILTER→count card and no decision/routing card.
- fuzzy-sum's pill said "exact sum," which trips verify-showcase's `"exact" in
  pill` llm exact-gate — but aur-0's honor-matrix just proved NO reachable
  backend honors `_seed`, so exact-gating llm output isn't viable.

## After state

- `fuzzy-count` card: `{$0+$1}⊘({$0~>'a complaint'}↦[...])` → 2 (msm-0's #2) —
  fuzzy filter → precise count; grep can't judge tone, a prompt can't count.
  Verified det → 0 (keyword), llm → 2. live-caption.
- `fuzzy-decide` card: `$if%('the server keeps crashing'~>'urgent','escalate','queue')`
  → escalate (aur-2) — NEW decision/routing category. Divergence hook: the SAME
  expr → `queue` in det (keyword) vs `escalate` in llm (semantic). Verified both.
- fuzzy pills reworded off "exact" → "precise" (fuzzy-sum + fuzzy-count) so they
  are live-caption, not locked llm assertions, per aur-0's guidance. Exactness
  stays in the captions. fuzzy-sum PNG re-rendered.
- README "Why nlir, not a prompt?" block: fuzzy-count paired with fuzzy-sum +
  the fuzzy-decide decision shape added.
- verify-showcase --det-only green (0 failed; all fuzzy cards live-caption/skip).

## Diff summary

- Code/content commit: `712f756` (`bd-e097c1`); final squash SHA from receipt.
- Files: `scripts/build-showcase.py` (+2 cards, fuzzy-sum pill reword),
  `README.md` (+fuzzy-count/fuzzy-decide in the Why-nlir block),
  `showcase/nlir-fuzzy-count.png` (new), `showcase/nlir-fuzzy-decide.png` (new),
  `showcase/nlir-fuzzy-sum.png` (re-rendered).
- Tests: verify-showcase --det-only 3 exact / 8 ran-non-empty / 0 failed.
- Behavioural delta: the site's "why nlir" set now spans all four categories,
  and the fuzzy family is consistently live-caption (no unreproducible llm
  assertions).

## Embedded artefacts

- `showcase/nlir-fuzzy-count.png` — fuzzy filter → count (→ 2).
- `showcase/nlir-fuzzy-decide.png` — fuzzy decision/routing (→ escalate; det → queue).

## Operator-takeaway

The "why nlir, not a prompt" set now argues the full case on the site: semantic
vs structural access, fuzzy-sum and fuzzy-count (the two things neither grep nor
a prompt does), and fuzzy-decide (routing where the det/llm gap literally shows
what `~>` buys). Critically, when aur-0's honor-matrix proved `_seed` can't make
llm output reproducible on our stack, the fuzzy cards were kept as honest
live-captions rather than locked assertions — the site stays green and truthful.
