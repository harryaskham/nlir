#!/usr/bin/env bash
# nlir-golf (aur-2) — "the handshake problem": how many handshakes in a room of ten?
#
#     'ten' * ( 'ten' - 'one' ) / 'two'
#      └10┘     └10┘   └1┘        └2┘
#      └──── 10 * (10 - 1) / 2 = 10 * 9 / 2 = 45 ────┘
#
# If ten people each shake hands with everyone else, that's ten times nine handshakes --
# but every handshake got counted from both sides, so halve it: 45. The classic "n
# choose 2" combinatorics, written with a parenthesised subtraction inside a
# multiply-then-divide. Coercion reads all four number-words.
#
# Real output (claude-sonnet-5): 45
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR="'ten'*('ten'-'one')/'two'"

echo "concept:    the handshake problem -- 10 people, n(n-1)/2 = 10*9/2 = 45 handshakes"
echo "expression: 'ten'*('ten'-'one')/'two'"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
