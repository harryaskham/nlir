#!/usr/bin/env bash
# nlir TARGET-GOLF (aur-2 #48) — reverse game via : (simplify): CLIMATE-SCIENCE
# jargon -> plain, and : reaches for the "warm blanket" analogy on its own (11% shorter).
#
# TARGET (~174 chars):
#   "The greenhouse effect is when gases in the air act like a blanket around the
#    planet, trapping some of the sun's heat so the surface stays warmer than it
#    would be without them."
#
# EXPRESSION (155 chars):
#   :'the greenhouse effect is the process by which gases in a planet atmosphere trap heat from the sun and keep the surface warmer than it would otherwise be'
#
# Real output (claude-sonnet-5):
#   "Some gases in the air around a planet are like a warm blanket. They trap heat
#    from the sun and keep the ground nice and warm. Without them, the planet would
#    be much colder."
# Closeness: same mechanism (gases trap the sun's heat -> warmer surface), plain +
# the same blanket analogy (high), 11% shorter. : turns "atmosphere" into "the air".
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

TARGET="The greenhouse effect is when gases in the air act like a blanket around the planet, trapping some of the sun's heat so the surface stays warmer than it would be without them."
EXPR=":'the greenhouse effect is the process by which gases in a planet atmosphere trap heat from the sun and keep the surface warmer than it would otherwise be'"

echo "TARGET (${#TARGET} chars): $TARGET"
echo "EXPR   (${#EXPR} chars): $EXPR"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
