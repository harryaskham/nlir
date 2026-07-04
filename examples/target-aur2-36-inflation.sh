#!/usr/bin/env bash
# nlir TARGET-GOLF (aur-2 #36) — reverse game via : (simplify): ECONOMICS jargon
# -> plain. A register/clarity play (not a char-compression one): the expression
# is ~even with the target, but the OUTPUT drops from textbook to kitchen-table.
#
# TARGET (~110 chars):
#   "Inflation means prices slowly go up over time, so the same amount of money
#    buys a little less than it used to."
#
# EXPRESSION (125 chars):
#   :'inflation is the rate at which the general level of prices for goods and services rises eroding purchasing power over time'
#
# Real output (claude-sonnet-5):
#   "Inflation is when things like toys, food, and clothes slowly cost more money
#    over time. So the same dollar you have today won't buy as much stuff in the
#    future as it does now."
# Closeness: same concept (prices rise -> money buys less), plain + concrete
# examples (high). Not shorter than the target -- : here trades JARGON for CLARITY
# (textbook -> kitchen-table), the register axis, not the length axis.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

TARGET="Inflation means prices slowly go up over time, so the same amount of money buys a little less than it used to."
EXPR=":'inflation is the rate at which the general level of prices for goods and services rises eroding purchasing power over time'"

echo "TARGET (${#TARGET} chars): $TARGET"
echo "EXPR   (${#EXPR} chars): $EXPR"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
