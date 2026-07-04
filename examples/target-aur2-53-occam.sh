#!/usr/bin/env bash
# nlir TARGET-GOLF (aur-2 #53) — reverse game via : (simplify): PHILOSOPHY jargon
# (Occam's razor) -> a pithy plain-English maxim (a big compression win).
#
# TARGET (~157 chars):
#   "Occam's razor is the idea that if two explanations both fit the facts, the
#    simpler one -- the one with fewer assumptions -- is usually the right one."
#
# EXPRESSION (135 chars):
#   :'Occam razor is the principle that when faced with competing explanations the simplest one that fits the evidence is usually the best'
#
# Real output (claude-sonnet-5):
#   "When you have two ideas that both explain something, pick the simple one -- it's
#    usually right."
# Closeness: same principle (two rival explanations -> prefer the simpler), plain
# (high). : compressed the definition into a snappy MAXIM (~90 chars) -- dropping the
# "fewer assumptions" nuance but keeping the actionable core.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

TARGET="Occam's razor is the idea that if two explanations both fit the facts, the simpler one -- the one with fewer assumptions -- is usually the right one."
EXPR=":'Occam razor is the principle that when faced with competing explanations the simplest one that fits the evidence is usually the best'"

echo "TARGET (${#TARGET} chars): $TARGET"
echo "EXPR   (${#EXPR} chars): $EXPR"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
