# Session summary — seed docs/design/composable-core.md (APL/J composable core)

## Goal

Harry's APL/J refinement loop, my owned 4-way-split slice: seed + own the shared
composable-core design doc (design-by-programming: runnable exemplar programs +
adverb specs), with sections dropped in from msm-1 (cat-theory/trains) + aur-1
(train grammar) + aur-0 (ranking).

## Bead(s)

- `bd-fd3a37` — `$filter`/where builtin (I filed the spec; IMPLEMENTED by
  msm-0/aur-2 @d7f6f6c during the loop — closing).

## Before state

- No composable-core design doc; APL/J refinement scattered in chat. filter/scan
  absent.

## After state

- `docs/design/composable-core.md` seeded (shared anchor, one file everyone
  appends): existing-core inventory; 5 verified det exemplar programs (map∘fold,
  split→map→fold, do-N power, word-count = sum∘map(const 1)∘split → 6); the mixed
  text+det urgent-digest target; the adverb family — filter + scan now marked
  LANDED @d7f6f6c with corrected det examples (`$filter%({$0},[true,false,true])`
  → `[true,true]`; `$scan%({$0+$1},[1,2,3,4])` → `[1,3,6,10]`); trains as the
  remaining #1 point-free gap; msm-1's cat-theory §4 (fork=parallel-then-combine)
  + aur-1's train-grammar §5 (parse desugar, atop/fork, zero glyphs) + aur-0's
  ranking §6.

## Diff summary

- Content commit: pending final squash SHA from the reintegration receipt.
- Files: `docs/design/composable-core.md` (new).
- No code change; all cited exemplars verified with `nlir -e … --mode det`
  (P1–P5 + word-count → 6; filter/scan post-landing). Checkout hard-synced to
  d7f6f6c first to avoid reverting others' landed config det-stubs.

## Operator-takeaway

The composable core completed its functional spine this session — map/filter/
fold/scan all land as deterministic word-builtins, and "functions" like length
and word-count fall out of composing them rather than being hard-coded (the
thesis). The doc pins verified exemplars as a regression surface and leaves the
point-free trains story (zero-glyph parser desugar) as the last big primitive,
now in msm-0's parser lane.
