#!/usr/bin/env bash
# nlir-golf (aur-2) — "the triangle": area = 1/2 * base * height, with the
# dimensions spelled out as words.
#
#     '0.5' * 'twelve' * 'five'
#      └ 0.5 ┘  └ 12 ┘    └ 5 ┘
#      └──── 0.5 * 12 * 5 = 30 ────┘
#
# 1/2 * base * height: a base of twelve and a height of five give an area of 30.
# The decimal half sits next to two worded dimensions and it all just multiplies.
#
# Real output (claude-sonnet-5): 30
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR="'0.5'*'twelve'*'five'"

echo "concept:    area of a triangle, 1/2 * base * height, over worded dimensions"
echo "expression: '0.5'*'twelve'*'five'   (0.5 * 12 * 5)"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
