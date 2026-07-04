#!/usr/bin/env bash
# nlir TARGET-GOLF (aur-2 #66) — reverse game via : (simplify): ECONOMICS jargon
# -> plain, 14% shorter.
#
# TARGET (~179 chars):
#   "A recession is when the economy shrinks for a while -- usually two quarters in
#    a row of falling output -- so businesses slow down, hiring drops, and money
#    gets tighter for everyone."
#
# EXPRESSION (154 chars):
#   :'a recession is a significant widespread and prolonged decline in economic activity typically defined as two consecutive quarters of negative GDP growth'
#
# Real output (claude-sonnet-5):
#   "A recession is when the economy has a really bad time for a while -- people buy
#    less stuff, businesses make less money, and things slow down a lot. This usually
#    has to be true for at least six months in a row for people to call it a recession."
# Closeness: same idea (sustained economic decline, ~two quarters / six months),
# plain (high), 14% shorter. : renders "GDP"/"two quarters" as "six months in a row".
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

TARGET="A recession is when the economy shrinks for a while -- usually two quarters in a row of falling output -- so businesses slow down, hiring drops, and money gets tighter for everyone."
EXPR=":'a recession is a significant widespread and prolonged decline in economic activity typically defined as two consecutive quarters of negative GDP growth'"

echo "TARGET (${#TARGET} chars): $TARGET"
echo "EXPR   (${#EXPR} chars): $EXPR"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
