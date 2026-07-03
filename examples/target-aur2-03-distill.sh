#!/usr/bin/env bash
# nlir TARGET-GOLF (aur-2 #03) — reverse game via ~> (summary of expand):
# CONTROLLED-length rich generation.
#
# > (expand) alone over-elaborates a seed into a multi-paragraph essay (~880
# chars here). Wrapping it in ~ (summary) distils that back to ONE dense line --
# so a few keywords regenerate a tight, information-rich sentence. (aur-2 target
# lane = > / : ; this is the length-control trick for it.)
#
# TARGET (105 chars):
#   "Regular exercise strengthens your heart, lifts your mood, boosts your energy, and helps you sleep better."
#
# EXPRESSION (41 chars):
#   ~>'the main benefits of regular exercise'
#
# Real output (claude-sonnet-5):
#   "Regular physical activity delivers lasting benefits to physical health, mental wellbeing, and overall quality of life."
# Closeness: same topic, one-sentence length (117 vs 105 chars; raw > alone was
# ~880). ~> = expand for richness, summarise for fit.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

TARGET="Regular exercise strengthens your heart, lifts your mood, boosts your energy, and helps you sleep better."
EXPR="~>'the main benefits of regular exercise'"

echo "TARGET (${#TARGET} chars): $TARGET"
echo "EXPR   (${#EXPR} chars): $EXPR"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
