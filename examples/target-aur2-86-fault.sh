#!/usr/bin/env bash
# nlir TARGET-GOLF (aur-2 #86) — reverse game via : (simplify): GEOLOGY jargon
# (a fault) -> plain, 25% shorter.
#
# TARGET (~180 chars):
#   "A fault is a crack in the Earth's crust where two blocks of rock have slid past
#    each other -- and because that movement can happen suddenly, faults are where most
#    earthquakes strike."
#
# EXPRESSION (135 chars):
#   :'a fault is a fracture in the earths crust along which blocks of rock have moved relative to each other often the site of earthquakes'
#
# Real output (claude-sonnet-5):
#   "A fault is a big crack in the ground. On both sides of the crack, huge chunks of
#    rock can slide and move past each other. When this happens, it can cause an
#    earthquake!"
# Closeness: same idea (a crack in the crust where rock blocks slide past each other ->
# earthquakes), plain (high), 25% shorter.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

TARGET="A fault is a crack in the Earth's crust where two blocks of rock have slid past each other -- and because that movement can happen suddenly, faults are where most earthquakes strike."
EXPR=":'a fault is a fracture in the earths crust along which blocks of rock have moved relative to each other often the site of earthquakes'"

echo "TARGET (${#TARGET} chars): $TARGET"
echo "EXPR   (${#EXPR} chars): $EXPR"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
