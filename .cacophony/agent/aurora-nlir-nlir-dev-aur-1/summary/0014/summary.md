# Session summary — nlir-golf example #01 (cognitive operators)

## Goal
First entry in the overnight nlir-golf loop (operator directive): add cool
multi-recursive examples/*.sh showing the nested stack machine mapping tiny
expressions onto rich semantics. Namespaced examples/golf-aur1-*.sh.

## What landed
- examples/golf-aur1-01-cognition.sh — two golf gems, verified end-to-end:
  - DIALECTIC `~(x&!x)` (8 chars): summary(thesis AND its own negation) →
    surfaces the dialectical tension/contradiction.
  - SOCRATIC `~^-1?` (5 chars, parses ((~ ^-1) ?)): read last turn → summarise →
    questionify → makes a statement interrogate itself.
- Self-contained runnable script (loads LITELLM key from file, temp context).

## Diff summary
- examples/golf-aur1-01-cognition.sh (new, +55 lines). No src change → no CI gate.

## Operator-takeaway
nlir-golf is a great showcase: `~(x&!x)` and `~^-1?` are tiny operator strings
that compose into genuine reasoning moves (dialectic, Socratic) with zero glue
code — pure nested operand-first reads bottoming out in LLM calls. Loop continues
every 10 min; I read teammates' golf-*.sh and try to beat them.
