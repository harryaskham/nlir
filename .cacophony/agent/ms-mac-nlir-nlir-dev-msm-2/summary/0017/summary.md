# Session summary — golf→site: access duality (`.`/`..`) + fuzzy-sum flagship cards

## Goal

Continue Harry's golf rally in the site/showcase-card lane: convert confirmed
"why nlir, not a prompt" shapes into first-class site cards (showcase PNGs).
This chunk: complete the `.`↔`..` access duality on the site, and card-ify
msm-0's referee-confirmed flagship det+fuzzy pipe example.

## Bead(s)

- `bd-2b9354` — showcase: `.` structural-access card, completing the `.`↔`..`
  duality (`[Mercury,Venus,Earth,Mars].2` → Earth).
- `bd-f2c97b` — showcase: `fuzzy-sum` pipe card, the det+fuzzy flagship
  (`{$0+$1}⊘(['3 apples','5 oranges','2 pears'])` → 10). Candidate from msm-0.
- (prior this session: `bd-e84379` — the first `..` semantic-access card, landed
  as d3e0bb5e2.)

## Before state

- After bd-e84379 the site had the `..` semantic-access card but NO `.`
  structural-access card — the signature access duality was only half shown.
- No showcase card existed for the det+fuzzy pipe "signature mix," even though
  msm-0's Family B (pipe det/fuzzy) had landed as example scripts + phrasebook.
- verify-showcase: 2 exact-verified.

## After state

- `structural-access` card: `[Mercury,Venus,Earth,Mars].2` → "Earth"
  (det · exact). Pairs with `..`: same target, two access modes — Earth by
  COUNTING a real list vs by MEANING (`sol..3`). verify-showcase EXACT-checks it.
- `fuzzy-sum` card: `{$0+$1}⊘(['3 apples','5 oranges','2 pears'])` → "10"
  (llm+det · fuzzy-extract → exact sum). The model reads each fuzzily-worded
  count, the exact `+` sums — the "why nlir, not a prompt" flagship. det errors
  on "3 apples"→number (proving the fuzzy half needs the model); live → 10,
  self-verified + msm-0/aur-0 confirmed.
- Both PNGs rendered. verify-showcase --det-only: 3 exact-verified, 0 failed.

## Diff summary

- Code/content commit: `7cd32fd` (`bd-2b9354`, `bd-f2c97b`); final landed squash
  SHA from the reintegration receipt.
- Files touched: `scripts/build-showcase.py` (+2 SIMPLE cards),
  `showcase/nlir-structural-access.png` (new), `showcase/nlir-fuzzy-sum.png` (new).
- Tests: verify-showcase --det-only 3 exact / 8 ran-non-empty / 0 failed
  (structural-access newly EXACT-gated); verify-spec-ops unaffected.
- Behavioural delta: the site now tells the full `.`↔`..` duality and carries
  the flagship det+fuzzy pipe card. No new example scripts (msm-0 owns
  move-msm0-pipe.sh); this is pure site-card integration.

## Embedded artefacts

- `showcase/nlir-structural-access.png` — `[Mercury,Venus,Earth,Mars].2` → Earth.
- `showcase/nlir-fuzzy-sum.png` — `{$0+$1}⊘([...])` → 10.

## Operator-takeaway

The golf→site loop is now a repeatable pipeline: agents referee "why nlir"
shapes live, msm-2 turns the confirmed winners into CI-gated showcase cards.
This chunk shipped the two most instructive: the `.`↔`..` access duality (exact
structural vs semantic, same "Earth" two ways) and the flagship det+fuzzy pipe
(`fuzzy-sum` → 10, the one no single tool can do). The site now argues "why
nlir, not a prompt" with real, reproducible executions, not prose.
