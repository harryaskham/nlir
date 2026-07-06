# Session summary — composable-core.md final batch: ~> det + capstones (core complete)

## Goal
Final composable-core.md pass now the last det gap closed (`~>` det-bool @e490e58)
and msm-0 declared the composable seed COMPLETE. Fold in the ~>-det, add the
deepest-composition capstone exemplars, mark the core complete.

## Bead(s)
- (context: @e490e58 `det:` field + `~>` det = real Bool — msm-0 eval/config lane)

## Before state
- Doc §2/§3.2 said the `~>` classify "awaits its det-bool stub" (stale); the mixed
  urgent-digest target was marked not-yet-det.

## After state
- §2 urgent-digest note: now FULLY det-runnable via `~>`→contains
  (`…$filter%({$contains%($0,"urgent")}…)` → `urgent A!|urgent C!`, verified).
- §2 exemplars P12–P15: P12 correctness-count (det ~> → 2, fuzzy-classify→det-count
  no llm), P13 aur-0's 5-primitive capstone grade+branch (map+~>+fold+comparison+$if
  → PASS), P14 smallest-passing (filter→sort→nth → 5), P15 max-of-squares
  (map→sort→nth → 16).
- §3.2: `~>` det-bool marked landed (@e490e58); filter-by-containment det example.
- §3 intro: **composable seed COMPLETE** (msm-0, no more primitives per Harry's
  "don't add every function"; aur-0+msm-0 stress-validated 4–5-primitive comps,
  zero footguns). Remaining = ergonomics only (tacit %-free application, % right-assoc,
  zip).

## Diff summary
- Content commit: pending final squash SHA.
- Files: `docs/design/composable-core.md`. No code; P12–P15 + the urgent-digest det
  skeleton all re-verified on the rebased checkout (@e490e58).

## Operator-takeaway
The composable core is DONE: a tiny primitive set (map/filter/fold/scan +
$if/$nth/$sort + comparisons + atop/fork trains + ++/// strings + the det: computed
stub) composes into real 4–5-line programs — grade-and-branch, correctness-count,
smallest-passing, order statistics — every one deterministic and offline, including
the fuzzy-classify→det-count that is Harry's thesis made testable. No new
primitives needed; only ergonomics (tacit application, % right-assoc) remain.
