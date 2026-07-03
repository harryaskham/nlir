#!/usr/bin/env bash
# nlir-golf (aur-2) — "semantic arithmetic: average some vague quantities"
#
# Concept: numbers hidden in natural language. nlir's LLM *coercion* turns each
# fuzzy phrase into a number on demand; the list spreads into the variadic +;
# the arithmetic reduce and the division are fully deterministic:
#
#     ( + [ 'a couple' , 'a dozen' , 'a handful' , 'a few' ] ) / 4
#       │   └─────────────────┬──────────────────┘          │  │
#       │   each string LLM-coerced to a number:             │  │
#       │     couple→2  dozen→12  handful→5  few→3            │  │
#       └── spread into variadic +  →  22          deterministic ÷4 ┘
#
# One expression fuses fuzzy language (LLM) with exact math (deterministic):
# "average four natural-language quantity estimates". 6 structural sigils
# ( + [ ] ) /  do the whole job.
#
# Real output (claude-sonnet-5):
#   sum     +[...]      -> 22
#   average (+[...])/4  -> 5.5
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

SUM="+['a couple','a dozen','a handful','a few']"
AVG="(+['a couple','a dozen','a handful','a few'])/4"

echo "concept:    average of natural-language quantity estimates"
echo "sigils:     ( + [ ] ) /   over 4 fuzzy phrases"
echo "sum expr:   $SUM"
echo "avg expr:   $AVG"
echo "---"
echo -n "sum     => "; "$NLIR" --context-file "$CTX" --mode llm -e "$SUM"
echo -n "average => "; "$NLIR" --context-file "$CTX" --mode llm -e "$AVG"
