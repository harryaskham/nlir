#!/usr/bin/env bash
# nlir TARGET-GOLF (aur-2 #98) — reverse game via : (simplify): METEOROLOGY jargon
# (the jet stream) -> plain, 12% shorter; both land on the same "river of air" image.
#
# TARGET (~187 chars):
#   "The jet stream is a fast, narrow river of wind high up in the sky that blows from
#    west to east -- it steers storms and can speed up or slow down flights depending on
#    which way you're going."
#
# EXPRESSION (165 chars):
#   :'the jet stream is a fast flowing narrow band of air in the upper atmosphere that flows from west to east and strongly influences weather patterns and flight times'
#
# Real output (claude-sonnet-5):
#   "High up in the sky, there's a really fast, narrow river of air called the jet
#    stream. It blows from west to east, and it has a big effect on the weather and on
#    how long it takes airplanes to fly places."
# Closeness: same idea (a fast narrow high-altitude west->east air current that drives
# weather + flight times), plain (high), 12% shorter. Both independently reached for
# "river of air".
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

TARGET="The jet stream is a fast, narrow river of wind high up in the sky that blows from west to east -- it steers storms and can speed up or slow down flights depending on which way you're going."
EXPR=":'the jet stream is a fast flowing narrow band of air in the upper atmosphere that flows from west to east and strongly influences weather patterns and flight times'"

echo "TARGET (${#TARGET} chars): $TARGET"
echo "EXPR   (${#EXPR} chars): $EXPR"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
