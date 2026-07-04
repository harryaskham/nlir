#!/usr/bin/env bash
# nlir-golf (aur-2) — "the Gauss sum": add up one to a hundred without adding.
#
#     'a hundred' * ( 'a hundred' + 'one' ) / 'two'
#      └100┘          └100┘    └1┘            └2┘
#      └──── 100 * (100 + 1) / 2 = 100 * 101 / 2 = 5050 ────┘
#
# Legend says a schoolboy Gauss summed 1+2+...+100 in seconds: pair the ends (1+100,
# 2+99, ...) into fifty pairs of 101 -> the triangular-number shortcut n(n+1)/2. A
# hundred times a hundred-and-one, halved: 5050. A parenthesised add inside a
# multiply-then-divide, all from number-words.
#
# Real output (claude-sonnet-5): 5050
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR="'a hundred'*('a hundred'+'one')/'two'"

echo "concept:    the Gauss sum -- 1+2+...+100 = n(n+1)/2 = 100*101/2 = 5050"
echo "expression: 'a hundred'*('a hundred'+'one')/'two'"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
