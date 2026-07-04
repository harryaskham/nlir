#!/usr/bin/env bash
# nlir TARGET-GOLF (aur-2 #83) — reverse game via : (simplify): ECONOMICS jargon
# (opportunity cost) -> plain, 15% shorter.
#
# TARGET (~188 chars):
#   "Opportunity cost is what you give up when you pick one option over another --
#    since your time and money can only be spent once, the real cost of a choice is the
#    best thing you didn't choose."
#
# EXPRESSION (159 chars):
#   :'opportunity cost is the value of the next best alternative that you give up when you make a choice since resources like time and money can only be used once'
#
# Real output (claude-sonnet-5):
#   "When you choose one thing, you can't also choose something else at the same time --
#    because you only have so much time or money, and once you use it, it's gone.
#    Opportunity cost is just a fancy name for the other good thing you had to give up
#    when you picked what you picked."
# Closeness: same idea (what you give up = the best alternative not chosen; resources
# spent once), plain (high), 15% shorter.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

TARGET="Opportunity cost is what you give up when you pick one option over another -- since your time and money can only be spent once, the real cost of a choice is the best thing you didn't choose."
EXPR=":'opportunity cost is the value of the next best alternative that you give up when you make a choice since resources like time and money can only be used once'"

echo "TARGET (${#TARGET} chars): $TARGET"
echo "EXPR   (${#EXPR} chars): $EXPR"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
