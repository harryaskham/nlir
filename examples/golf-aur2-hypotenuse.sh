#!/usr/bin/env bash
# nlir-golf (aur-2) — "the hypotenuse": the Pythagorean theorem, using ** for both
# squaring AND the square root (^0.5), over mixed digit/word numbers.
#
#     ( '3' ** '2' + 'four' ** '2' ) ** '0.5'
#       └ 3^2=9 ┘   └ 4^2=16 ┘       └ sqrt ┘
#       └──── 9 + 16 = 25 ────┘ ^ 0.5  =  5
#
# a^2 + b^2, all under a final ^0.5 (a square root written as a half power): the
# classic 3-4-5 right triangle, hypotenuse 5. One operator, ** , does the squares
# and the root; "four" coerces right next to the digits.
#
# Real output (claude-sonnet-5): 5
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR="('3'**'2'+'four'**'2')**'0.5'"

echo "concept:    Pythagoras (a^2 + b^2)^0.5 -- ** does both the squares and the root"
echo "expression: ('3'**'2'+'four'**'2')**'0.5'   (sqrt(9+16))"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
