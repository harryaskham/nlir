#!/usr/bin/env bash
# nlir-golf (aur-2) — "squares on a chessboard": not 64 -- count every size.
#
#     'eight' * ( 'eight' + 'one' ) * ( 'two' * 'eight' + 'one' ) / 'six'
#      └8┘       └8┘    └1┘            └2┘  └8┘     └1┘               └6┘
#      └──── 8 * (8+1) * (2*8+1) / 6 = 8 * 9 * 17 / 6 = 1224 / 6 = 204 ────┘
#
# A chessboard has 64 unit squares -- but how many squares of ANY size (1x1, 2x2, ...,
# 8x8)? Sum the first eight squares: 1+4+9+...+64 = n(n+1)(2n+1)/6 = 204. Two nested
# parentheses -- an add, and a multiply-then-add (precedence puts the double before the
# plus-one) -- feed a multiply-then-divide. Coercion reads every number-word.
#
# Real output (claude-sonnet-5): 204
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR="'eight'*('eight'+'one')*('two'*'eight'+'one')/'six'"

echo "concept:    squares of all sizes on a chessboard -- sum 1..8 squared = n(n+1)(2n+1)/6 = 204"
echo "expression: 'eight'*('eight'+'one')*('two'*'eight'+'one')/'six'"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
