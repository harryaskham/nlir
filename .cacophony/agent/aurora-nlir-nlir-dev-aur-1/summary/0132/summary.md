# Session summary — golf #119 (parens are load-bearing) + target #117 (evidence)

## What landed
- examples/golf-aur1-119-parens.sh — PARENS ARE LOAD-BEARING: `!(a&b) ≠ !a&b` — grouping sets an
  operator's SCOPE. !(a&b) → "the tests do not pass AND the build does not work" (! negates the WHOLE
  group, both false); !a & b → "the tests do not pass AND the build works" (! binds ONLY to a; b
  untouched). Watch b: negated with parens, untouched without. So !(a&b) and !a&b are DIFFERENT
  PROGRAMS (structural at PARSE), not formatting. nlir has TWO kinds of parens: STRUCTURAL (load-
  bearing, sets scope, this) vs COSMETIC ECHO (the stray "(" the model prints — a display bug, fix
  prototyped). Rule: widen an operator's reach with parens (!(a&b&c) = falsify all), drop them to pin
  it to the first operand. (Deterministic — pivoted here after @(x?)≠@x? precedence proved to be LLM
  variance, both formal questions, unreliable.)
- examples/target-aur1-117-evidence.sh — 106th `?` framing: 'what does the data say'? (24c) → "What
  does the data say?" ground the argument in EVIDENCE not opinion (vs #93 measurement, #113 Occam).

## Notes
- Harry trains/lambda consolidated; operator spec + paren-echo fix (COSMETIC echo, distinct from
  #119's structural parens) queued for green-light.
