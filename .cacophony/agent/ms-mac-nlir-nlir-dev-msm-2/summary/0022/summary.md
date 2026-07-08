# Session summary — reusable-part pyramid card (named part → decision train)

## Goal

Turn Harry's live "pyramid of thought" exploration into a shipped site card
(active burndown, not unbeaded chat): a reusable named PART driving a full
decision train, as the L3/L4 capstone of the "why nlir" set.

## Bead(s)

- `bd-ca31ab` — showcase: `reusable-part` pyramid card (named part → train).

## Before state

- The team (Harry-directed) was live-building the "pyramid": name a thought-unit
  once (a form), compose parts into trains. Verified live + captured in the
  shared `nlir-parts-library` scratch note, but the pyramid was unbeaded.
- The "why nlir" showcase set had access·pipe·decision·generation·self-judge but
  no reusable-parts/pyramid card.

## After state

- `reusable-part` card: `urgent={$0~>'urgent'}; $if%($fold%({$0+$1},$urgent↦['server
  is down','lunch plans','payments failing'])>=2,'page the on-call engineer','queue
  for morning')` → "page the on-call engineer" live (2 urgent ≥ 2) vs "queue for
  morning" in det. One reusable fuzzy part drives map→count→threshold→route; the
  det/llm gap is what the fuzzy part buys. Live-verified by msm-2.
- Added to the README "Why nlir, not a prompt?" block as the pyramid entry.
- Round-trip note honored: the `urgent` part is bare-safe (`'urgent'`→`urgent`),
  so it works as a named part on current main; prose-prompt parts fast-follow
  msm-3's render-with-quotes fix (bd-4fb6d0).
- verify-showcase --det-only green (0 failed); live-caption.

## Diff summary

- Code/content commit: `b9ae793` (`bd-ca31ab`); final squash SHA from receipt.
- Files: `scripts/build-showcase.py` (+1 card), `README.md` (+pyramid block),
  `showcase/nlir-reusable-part.png` (new).
- Tests: verify-showcase --det-only 3 exact / 8 ran-non-empty / 0 failed.
- Behavioural delta: the site now shows the reusable-parts pyramid — a named part
  composed into a decision train.

## Embedded artefacts

- `showcase/nlir-reusable-part.png` — reusable `urgent` part → count → route.

## Operator-takeaway

Harry's pyramid became a shipped card: the same fuzzy predicate, named once,
composes into a whole decision train, and (per the team's live boundary finding)
bare-safe parts round-trip today while prose-prompt parts wait on the render fix.
Complements msm-0's runnable pyramid script — script proves it runs, card puts it
on the site. The library IS the pyramid: build a part once, every later train is
cheaper.
