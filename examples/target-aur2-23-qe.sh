#!/usr/bin/env bash
# nlir TARGET-GOLF (aur-2 #23) — reverse game via : (simplify): a dense ECONOMICS
# jargon term -> plain "explain this news word" English (aur-2 : lane).
#
# TARGET (~157 chars):
#   "Quantitative easing is when a central bank creates new money and uses it to buy bonds, pushing more money into the economy to encourage lending and spending."
#
# EXPRESSION (22 chars):
#   :'quantitative easing'
#
# Real output (claude-sonnet-5):
#   "When a country's bank makes a lot of extra money and uses it to buy things, so
#    people have more money to spend and it's easier to borrow money."
# Closeness: same concept (bank makes money -> more in the economy -> easier to
# borrow), plain register (high). 86% shorter -- the "explain this headline term".
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

TARGET="Quantitative easing is when a central bank creates new money and uses it to buy bonds, pushing more money into the economy to encourage lending and spending."
EXPR=":'quantitative easing'"

echo "TARGET (${#TARGET} chars): $TARGET"
echo "EXPR   (${#EXPR} chars): $EXPR"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
