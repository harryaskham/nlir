#!/usr/bin/env bash
# nlir-golf (aur-2) — "a googol": ten to the power of a hundred, spelled out --
# the number a googol names, and where Google got its name.
#
#     'ten' ** 'a hundred'
#      └ 10 ┘    └ 100 ┘
#      └── 10 ** 100 = 1 followed by 100 zeros ──┘
#
# Coercion reads both worded numbers and the (right-associative) power operator
# raises 10 to the 100th: a googol -- a 1 with a hundred zeros, printed exactly, no
# scientific-notation rounding. Two words, an astronomically large number.
#
# Real output (claude-sonnet-5):
#   10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR="'ten'**'a hundred'"

echo "concept:    a googol -- ten to the power of a hundred (10^100)"
echo "expression: 'ten'**'a hundred'"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
