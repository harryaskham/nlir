# Session summary — nlir help: branch/index/sort examples (bd-502b6c)

## Goal

bd-502b6c (follow-up part 1 to bd-5c19c4): now that the composable-core BASICS
landed + went green ($if branch, $nth index incl. negative-from-end, $sort
reorder), add a "branch / index / sort" examples group to `nlir help`, including
the derived order-statistic idioms msm-0/aur-0 flagged as phrasebook-worthy
(min/max via $nth + $sort).

## What landed

- `src/main.rs` (print_help_examples): new "branch / index / sort — control flow
  + order" group with 7 verified examples:
  - `$if%(1,'yes','no')` → yes / `$if%(0,'yes','no')` → no (branch)
  - `$nth%(1,[10,20,30])` → 20 (0-based index)
  - `$nth%(-1,[10,20,30])` → 30 (negative index from the end)
  - `$sort%[3,1,2]` → 1 2 3 (sort ascending)
  - `$nth%(0,$sort%[30,4,100,2])` → 2 (min = first of sorted)
  - `$nth%(-1,$sort%[30,4,100,2])` → 100 (max = last of sorted)
  - min/max use the SAME list [30,4,100,2] for a clean order-statistics pairing.
- Every example is a verified `nlir test` case (cookbook-if-then/else,
  cookbook-nth, cookbook-sort, cookbook-sort-min, cookbook-sort-max) — help ≡
  `nlir test`, no new keys needed (the fleet's cookbook-sort-max already covered
  the max idiom; aligned my example to it rather than adding a duplicate).

## Verification

- `nlir test`: 81 passed / 0 failed.
- Both min/max idioms re-run in det mode → 2 and 100.
- Preflight: `cargo fmt --all --check`, `cargo clippy --all-targets -D warnings`,
  `cargo test --lib` (272) + `--bin nlir` (34) all green.

## Scope / follow-up

Part 1 (the landed basics) only. DEFERRED to part 2: the flagship $if with a
comparison / `~>` fuzzy condition (`$if%(cond~>'…',then,else)`) — needs the
comparison ops (aur-2/msm-1) + the `~>` det:-stub (msm-0/aur-2) to be
det-runnable.

## Operator-takeaway

`nlir help` now also teaches control flow + order: branch with $if, index (incl.
from-the-end) with $nth, sort with $sort, and — the neat part — min and max fall
out of $nth + $sort with no dedicated primitive (min = first of sorted, max =
last), the same "functions emerge from a composable core" thesis.
