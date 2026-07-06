# Session summary — composable-core.md batch: basics + comparisons + control flow

## Goal
Batch composable-core.md refresh now the det control-flow backbone landed
(value builtins $if/$nth/$sort, signed literals, comparisons == != <= >=), per my
batch plan — one pass, all exemplars re-verified.

## Bead(s)
- (context: @f2a50d5 $if/$nth/$sort, @4499f58 signed literals, @2521bf1 comparisons —
  all msm-0/aur-2 eval/config lane; I document + verify)

## Before state
- Doc §1/§2/§3 covered map/filter/fold/scan + trains + string ops; value builtins,
  comparisons, and control flow were noted as pending/incoming.

## After state
- §1 inventory: added branch (`$if`), index (`$nth`, -1=last), sort, compare
  (== != <= >=), and trains (atop/fork) rows.
- §2 exemplars: added P9 (COUNT flagship — `$fold%({$0+$1},$map%({$0>=5},[3,7,2,9]))`
  → 2, the correctness-gate), P10 (MAX/MIN as order-statistics-for-free via
  sort+nth → 5/1), P11 (BRANCH on a det comparison `$if%(3<=5,yes,no)` → yes).
- §3 intro: whole core LANDED; remaining follow-ups = tacit `%`-free application,
  `~>` det-bool stub, `%` right-assoc (awaiting greenlight), zip.

## Diff summary
- Content commit: pending final squash SHA from the receipt.
- Files: `docs/design/composable-core.md`. No code; every P1–P11 exemplar
  re-verified on the rebased checkout (count→2, if→yes/match, max→5, min→1,
  sort→1 2 3, filter→1 2 3, all green).

## Operator-takeaway
The deterministic control-flow backbone is complete: map/filter/fold/scan +
atop/fork trains + $if/$nth/$sort + comparisons. The flagship is the count idiom
— "how many pass a test" is compare→map→fold in one line, structure fully det —
and max/min fall out of sort+nth for free. The composable core now does transform,
select, reduce, running-reduce, branch, order, and point-free composition from a
tiny primitive set; only tacit `%`-free application + the `~>` det-bool remain.
