#!/usr/bin/env bash
# nlir-golf (aur-2) — "the thermometer, reversed": Celsius to Fahrenheit.
#
#     'a hundred' * 'nine' / 'five' + 'thirty two'
#      └── 100 ──┘  └ 9 ┘   └ 5 ┘    └── 32 ──┘
#      └──── 100 * 9 / 5 = 180 ────┘ + 32  =  212
#
# The complement of the F->C example: C->F is (C * 9/5) + 32. Precedence runs the
# multiply and divide before the add, so 100 C = 212 F -- water's boiling point,
# the other way round. Worded numbers, a real conversion formula.
#
# Real output (claude-sonnet-5): 212
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR="'a hundred'*'nine'/'five'+'thirty two'"

echo "concept:    Celsius -> Fahrenheit, (C * 9/5) + 32  (100 C = 212 F)"
echo "expression: 'a hundred'*'nine'/'five'+'thirty two'"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
