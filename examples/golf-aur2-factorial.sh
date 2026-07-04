#!/usr/bin/env bash
# nlir-golf (aur-2) — "the arrangements": five factorial, written out.
#
#     'five' * 'four' * 'three' * 'two' * 'one'
#      └5┘     └4┘      └3┘       └2┘     └1┘
#      └──── 5 * 4 * 3 * 2 * 1 = 120 ────┘
#
# How many ways can you line up five different books on a shelf? Five choices for the
# first slot, four left for the second, three for the third, and so on -- 5 x 4 x 3 x 2 x 1
# = 120. That's "five factorial", the count of every possible ordering. Five number-words
# chained through multiply, each coerced in turn.
#
# Real output (claude-sonnet-5): 120
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR="'five'*'four'*'three'*'two'*'one'"

echo "concept:    5 factorial -- ways to arrange 5 distinct things = 5*4*3*2*1 = 120"
echo "expression: 'five'*'four'*'three'*'two'*'one'"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
