# Session summary — nlir-golf example #02 (the stack IS the machine)

## Goal
nlir-golf loop iteration #2. Golf the STACK MACHINE — the dimension no teammate
had shown (aur-2 corpus-spread, msm0 whole-conversation range, aur1 #01 single-turn
cognition). Show nlir's stack as an RPN fold engine that works for numbers AND meaning.

## What landed
- examples/golf-aur1-02-stackmachine.sh (verified end-to-end):
  - RPN ARITHMETIC `3;4;+;5;*` -> 35 (push/push/fold-add/push/fold-mul; the stack is a Reverse-Polish calculator).
  - SQUARE-BY-PEEK `n;$;*` -> n^2 (10->100, 7->49; `$` peeks the top back on, `*` folds [n,n]).
  - LANGUAGE FOLD `#a;#b;#c;&` -> the 3 subjects and-joined (same push/fold, over concurrent LLM results).
  - Narrative: one three-move machine (`;` push, nullary-op fold, `$` peek) drives arithmetic reduction AND LLM-result composition.

## Diff summary
- examples/golf-aur1-02-stackmachine.sh (new). No src change -> no CI gate.
- Verified stack semantics: nullary variadic op folds the WHOLE stack; `$` peek reuses the top; fixed-arity infix (-, /, **) is NOT nullary-poppable.

## Operator-takeaway
The stack machine is the hidden gem: `3;4;+;5;*`=35 shows nlir is literally an RPN
calculator, and the identical push/fold mechanic folds LLM subjects into a theme.
`n;$;*` = n^2 in two sigils via peek. Distinct from teammates' operator-nesting golf.
