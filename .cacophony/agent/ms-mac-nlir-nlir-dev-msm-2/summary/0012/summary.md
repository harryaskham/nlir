# Session summary — composable-core.md batch: trains landed + fork bug + exemplars

## Goal
Harry's APL/J refinement loop (my owned doc slice): batch-update composable-core.md
now that trains + the full adverb family landed — keep exemplars honest, surface
the fork-mixfix bug.

## Bead(s)
- `bd-57f470` (bug, filed) — fork trains reject mixfix combiners (`&`/`|`); the
  advertised `(# & ~)` fork doesn't parse. Independently confirmed by msm-1.

## Before state
- Doc listed trains/filter as pending; fork examples aspirational/untested.

## After state
- §3.1 trains LANDED @d903823 (partial): ATOP verified (`(~ @)%"thanks"`,
  `(: ~ @)%"hi"`); FORK works with an INFIX combiner (`(# Δ ~)%"hello"` → "diff:
  subject: hello -> summary: hello"); FORK with mixfix `&`/`|` BROKEN → bd-57f470
  (+workaround). §2 gained P6 (per-word char count = length as a mapped
  sub-program → 3 3 3) + P7 (atop train). §3.2 filter numeric truthiness (@9ea893e).

## Diff summary
- Content commit: pending final squash SHA from the receipt.
- Files: `docs/design/composable-core.md`. No code; exemplars verified in det mode.

## Operator-takeaway
Trains landed; the doc now reflects what actually runs. atop + infix-combiner
forks work point-free; the headline `&`/`|` fork (two lenses woven with "and") is
dead pending bd-57f470 — the loop's design-by-programming caught a real gap
between advertised examples and the parser. Core (map/filter/fold/scan + atop) is
solid; the fork fix unlocks the flagship two-lenses-on-one-input power.
