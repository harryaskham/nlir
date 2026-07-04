#!/usr/bin/env bash
# nlir TARGET-GOLF (aur-2 #43) — reverse game via : (simplify): METEOROLOGY jargon
# -> plain, and : turns "evaporates" into "turns into mist" (13% shorter too).
#
# TARGET (~201 chars):
#   "A hurricane starts when the sun heats the ocean, warm wet air rises off the
#    water and starts spinning, and it keeps growing stronger as long as it can
#    keep pulling in more warm, moist air from the sea."
#
# EXPRESSION (174 chars):
#   :'a hurricane forms when warm ocean water evaporates and rises creating a spinning system of clouds and wind that strengthens as it draws more heat and moisture from the sea'
#
# Real output (claude-sonnet-5):
#   "A hurricane starts when the warm ocean water turns into mist and floats up into
#    the sky. This makes clouds and wind start spinning around in a big circle. As
#    the spinning storm keeps soaking up more warm air and water from the sea, it
#    grows bigger and stronger."
# Closeness: same mechanism (warm water rises + spins + strengthens by drawing more
# heat/moisture), plain + vivid (high), 13% shorter. : renders "evaporates" as
# "turns into mist".
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

TARGET="A hurricane starts when the sun heats the ocean, warm wet air rises off the water and starts spinning, and it keeps growing stronger as long as it can keep pulling in more warm, moist air from the sea."
EXPR=":'a hurricane forms when warm ocean water evaporates and rises creating a spinning system of clouds and wind that strengthens as it draws more heat and moisture from the sea'"

echo "TARGET (${#TARGET} chars): $TARGET"
echo "EXPR   (${#EXPR} chars): $EXPR"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
