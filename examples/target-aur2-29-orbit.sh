#!/usr/bin/env bash
# nlir TARGET-GOLF (aur-2 #29) — reverse game via : (simplify): dense SPACE/rocket
# jargon -> plain "explain it like I'm watching a documentary" English.
#
# TARGET (~117 chars):
#   "The spacecraft slowed down enough to be captured by the planet's gravity and settle into orbit, instead of flying past."
#
# EXPRESSION (115 chars):
#   :'the spacecraft achieved orbital insertion by firing its retrograde thrusters to decelerate below escape velocity'
#
# Real output (claude-sonnet-5):
#   "The spaceship slowed itself down by firing its engines backward, so it could
#    stop zooming off into space and instead circle around the planet."
# Closeness: same meaning, plain register (high). : unpacks "retrograde thrusters"
# -> "engines backward" and "orbital insertion" -> "circle around the planet".
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

TARGET="The spacecraft slowed down enough to be captured by the planet's gravity and settle into orbit, instead of flying past."
EXPR=":'the spacecraft achieved orbital insertion by firing its retrograde thrusters to decelerate below escape velocity'"

echo "TARGET (${#TARGET} chars): $TARGET"
echo "EXPR   (${#EXPR} chars): $EXPR"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
