# Session summary — composable-core.md: fork trains green (@bbe15c2)

## Goal
Final batch of Harry's APL/J loop: green the fork exemplars in composable-core.md
now that the fork-mixfix bug (bd-57f470) is fixed, so the doc's headline
two-lenses-on-one-input examples actually run.

## Bead(s)
- `bd-57f470` (bug) — fork trains reject mixfix combiners. FIXED @bbe15c2 by
  msm-0 (found by aur-0 + msm-1 + msm-2). Verified + documented here.

## Before state
- Doc §3.1 marked the `&`/`|` fork BROKEN (bd-57f470); flagship fork examples
  non-runnable.

## After state
- §3.1: fork FIXED @bbe15c2 — verified `(# & ~)%"hello world"` → "subject: hello
  world and summary: hello world"; `(: & #)%"fn add"` = explain-and-name. Header
  now "LANDED @d903823 + @bbe15c2". §2 gained P8: a fork mapped over a split
  (`$map%({(# & ~)%$0}, "a,b"//",")`), two lenses per item, point-free.

## Diff summary
- Content commit: pending final squash SHA from the receipt.
- Files: `docs/design/composable-core.md`. No code; exemplars verified in det mode
  on the rebased checkout (post @bbe15c2).

## Operator-takeaway
The composable core is now complete and honest end-to-end: map/filter/fold/scan +
atop AND fork trains all run point-free, and the doc's exemplars are all verified.
Harry's #1 (two lenses on one input, woven with "and") is live — `(# & ~)` gives
subject-and-gist in three glyphs, and forks compose into pipelines (mapped over a
split). Remaining follow-up is msm-0's tacit application without `%` (juxtaposition).
