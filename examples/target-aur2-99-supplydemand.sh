#!/usr/bin/env bash
# nlir TARGET-GOLF (aur-2 #99) — reverse game via : (simplify): ECONOMICS jargon
# (the law of supply and demand) -> plain, 10% shorter.
#
# TARGET (~183 chars):
#   "The law of supply and demand says a thing's price depends on how much of it there
#    is versus how much people want it -- scarce and wanted means pricey, plentiful or
#    unwanted means cheap."
#
# EXPRESSION (165 chars):
#   :'the law of supply and demand states that the price of a good is determined by the relationship between how much of it is available and how much people want to buy'
#
# Real output (claude-sonnet-5):
#   "When there's a lot of something and not many people want it, it's cheap. When
#    there's only a little of something and lots of people want it, it costs more.
#    That's how prices are decided!"
# Closeness: same idea (price set by availability vs desire; scarce+wanted -> pricey,
# plentiful -> cheap), plain (high), 10% shorter.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

TARGET="The law of supply and demand says a thing's price depends on how much of it there is versus how much people want it -- scarce and wanted means pricey, plentiful or unwanted means cheap."
EXPR=":'the law of supply and demand states that the price of a good is determined by the relationship between how much of it is available and how much people want to buy'"

echo "TARGET (${#TARGET} chars): $TARGET"
echo "EXPR   (${#EXPR} chars): $EXPR"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
