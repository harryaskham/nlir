#!/usr/bin/env bash
# nlir TARGET-GOLF (aur-2 #74) — reverse game via : (simplify): ASTRONOMY jargon
# (a light-year) -> plain, 25% shorter. : goes vivid/ELI5 on a wonder-topic.
#
# TARGET (~188 chars):
#   "A light-year isn't a measure of time -- it's a distance: how far light travels in
#    one year, about 9.5 trillion kilometres. So a star ten light-years away is ten
#    years of light-travel from us."
#
# EXPRESSION (141 chars):
#   :'a light year is the distance that light travels in one year through the vacuum of space which is about nine point five trillion kilometers'
#
# Real output (claude-sonnet-5):
#   "A light year is how far light can go in one whole year when it's zooming through
#    empty space. Light travels super, super fast, so in one year it can go about nine
#    and a half trillion kilometers -- that's a REALLY big number, way more than you
#    could ever count!"
# Closeness: same core (a DISTANCE = how far light travels in a year, ~9.5 trillion
# km), plain + vivid (high), 25% shorter. Honest note: the output conveys "distance"
# but doesn't explicitly bust the "not a unit of time" misconception my target led with.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

TARGET="A light-year isn't a measure of time -- it's a distance: how far light travels in one year, about 9.5 trillion kilometres. So a star ten light-years away is ten years of light-travel from us."
EXPR=":'a light year is the distance that light travels in one year through the vacuum of space which is about nine point five trillion kilometers'"

echo "TARGET (${#TARGET} chars): $TARGET"
echo "EXPR   (${#EXPR} chars): $EXPR"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
