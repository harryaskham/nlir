# Session summary — self-verify capstone card (the self-verifying generator)

## Goal

Cap Harry's "pyramid of thought" with its peak as a site card: a SELF-VERIFYING
GENERATOR — nlir generates a thought from a terse seed AND checks its own work,
composed from two reusable library parts.

## Bead(s)

- `bd-178d5f` — showcase: `self-verify` capstone card (self-verifying generator).

## Before state

- The "why nlir" showcase set ran access·pipe·decision·generation·self-judge·
  reusable-part but had no capstone showing a train that *checks its own output*.
- The team live-established the sat-vs-j split: mutual `j` = golf equivalence;
  one-directional `sat={$0~>$1}` = generation satisfaction ("does the gen cover
  the intent"), the correct check for self-verifying generation (aur-0 flagged,
  msm-0 verified the full directional family live).

## After state

- `self-verify` card: `sat={$0~>$1}; brief={>@~$0}; $sat%($brief%'mobile
  onboarding spike next sprint','a plan to run a mobile onboarding feasibility
  spike next sprint')` → "true". brief expands a 4-word seed into a full plan;
  sat verifies the generation covers the intent (one-directional — a thorough
  answer passes; mutual is golf's job). Live-verified by msm-2: positive→true,
  negative(swapped seed)→false, mutual-j→false (the contrast).
- Added to the README "Why nlir, not a prompt?" block as the peak entry.
- verify-showcase --det-only green (0 failed); live-caption.

## Diff summary

- Code/content commit: `8eef557` (`bd-178d5f`); final squash SHA from receipt.
- Files: `scripts/build-showcase.py` (+1 card), `README.md` (+peak block),
  `showcase/nlir-self-verify.png` (new).
- Tests: verify-showcase --det-only 3 exact / 8 ran-non-empty / 0 failed.
- Behavioural delta: the site now shows nlir generating AND checking its own work.

## Embedded artefacts

- `showcase/nlir-self-verify.png` — brief generator + sat checker, self-verifying.

## Operator-takeaway

The pyramid's peak is now on the site: a short train of two reusable parts that
generates a thought and verifies it means what you asked — using the principled
one-directional `sat` (covers), not mutual `j` (golf equivalence). The card set
now tells the full "why nlir" story from single-op semantic access up to a
self-verifying generative train. Team-built: aur-0/msm-0 (sat/j), aur-1
(library), msm-3 (render fix unblocking prose parts).
