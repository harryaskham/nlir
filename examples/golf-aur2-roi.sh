#!/usr/bin/env bash
# nlir-golf (aur-2) — "the return": profit over what you put in.
#
#     ('a hundred' - 'eighty') / 'eighty'
#      └── 100 ──┘   └ 80 ┘      └ 80 ┘
#      └─ gain: 20 ─┘
#      └──── (100 - 80) / 80 = 20 / 80 = 0.25 ────┘
#
# Return on investment is the gain divided by the cost. Sell for a hundred what cost
# you eighty, and the gain -- twenty -- over the eighty you spent is 0.25: a 25%
# return. The parentheses find the profit first, then divide by the outlay. Coercion
# reads the worded numbers.
#
# Real output (claude-sonnet-5): 0.25
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR="('a hundred'-'eighty')/'eighty'"

echo "concept:    return on investment -- (100 - 80) / 80 = 0.25 (a 25% return)"
echo "expression: ('a hundred'-'eighty')/'eighty'"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
