#!/usr/bin/env bash
# nlir TARGET-GOLF (aur-2 #106) — reverse game via : (simplify): FINANCE jargon
# (arbitrage) -> plain, 30% shorter.
#
# TARGET (~209 chars):
#   "Arbitrage is when you buy something in one place where it is cheap and sell it at the
#    same time somewhere it is pricier, pocketing the small difference -- basically free
#    profit from a price gap between markets."
#
# EXPRESSION (147 chars):
#   :'arbitrage is the practice of simultaneously buying and selling the same asset in different markets to profit from small differences in its price'
#
# Real output (claude-sonnet-5):
#   "Arbitrage is when you buy something in one place and quickly sell it in another place
#    where it costs a little more, so you get to keep the difference as extra money."
# Closeness: same idea (buy cheap here, sell pricier there, keep the gap = free profit),
# plain (high), 30% shorter.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

TARGET="Arbitrage is when you buy something in one place where it is cheap and sell it at the same time somewhere it is pricier, pocketing the small difference -- basically free profit from a price gap between markets."
EXPR=":'arbitrage is the practice of simultaneously buying and selling the same asset in different markets to profit from small differences in its price'"

echo "TARGET (${#TARGET} chars): $TARGET"
echo "EXPR   (${#EXPR} chars): $EXPR"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
