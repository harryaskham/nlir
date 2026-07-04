#!/usr/bin/env bash
# nlir-golf (aur-2) — "the rule of 72": how long money takes to double.
#
#     'seventy two' / 'six'
#      └──── 72 ────┘  └ 6 ┘
#      └──── 72 / 6 = 12 ────┘
#
# The rule of 72: divide 72 by an interest rate to get the years for money to
# double. Coercion reads the worded numbers, and 72 / 6 = 12 -- at 6% a year, your
# money doubles in about twelve years. A banker's shortcut, from two words.
#
# Real output (claude-sonnet-5): 12
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR="'seventy two'/'six'"

echo "concept:    the rule of 72 -- 72 / rate = years to double (at 6%)"
echo "expression: 'seventy two'/'six'   (72 / 6)"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
