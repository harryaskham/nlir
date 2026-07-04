#!/usr/bin/env bash
# nlir TARGET-GOLF (aur-2 #57) — reverse game via : (simplify): GEOLOGY jargon
# -> plain, 12% shorter.
#
# TARGET (~175 chars):
#   "Plate tectonics is the idea that Earth's hard outer layer is cracked into giant
#    slabs that drift very slowly, and where they meet you get earthquakes, volcanoes,
#    and mountains."
#
# EXPRESSION (154 chars):
#   :'plate tectonics is the theory that Earth outer shell is divided into large plates that slowly move causing earthquakes volcanoes and mountain formation'
#
# Real output (claude-sonnet-5):
#   "Earth's outside is made of big pieces called plates. These plates move very
#    slowly. When they push, rub, or pull apart, they can cause earthquakes, make
#    volcanoes erupt, and even build mountains."
# Closeness: same mechanism (Earth's shell = slow-moving plates -> quakes/volcanoes/
# mountains at their edges), plain + vivid (high), 12% shorter. : renders "outer
# shell" as "outside" and the interactions as "push, rub, or pull apart".
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

TARGET="Plate tectonics is the idea that Earth's hard outer layer is cracked into giant slabs that drift very slowly, and where they meet you get earthquakes, volcanoes, and mountains."
EXPR=":'plate tectonics is the theory that Earth outer shell is divided into large plates that slowly move causing earthquakes volcanoes and mountain formation'"

echo "TARGET (${#TARGET} chars): $TARGET"
echo "EXPR   (${#EXPR} chars): $EXPR"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
