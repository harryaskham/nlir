#!/usr/bin/env bash
# nlir TARGET-GOLF (aur-2 #76) — reverse game via : (simplify): BIOLOGY jargon
# (osmosis) -> plain. : reaches for a tiny-holes + "sharing" analogy and runs a
# little long on an approachable topic (ELI5 register play).
#
# TARGET (~160 chars):
#   "Osmosis is when water moves through a thin barrier from the side with fewer
#    dissolved things to the side with more, evening out the concentration on both sides."
#
# EXPRESSION (164 chars):
#   :'osmosis is the movement of water molecules across a semipermeable membrane from a region of lower solute concentration to a region of higher solute concentration'
#
# Real output (claude-sonnet-5):
#   "Osmosis is when water moves through a special wall that has tiny holes just big
#    enough for water to pass through. The water moves from the side that has more water
#    and less 'stuff' mixed in, to the side that has less water and more 'stuff' mixed in
#    -- kind of like the water is trying to share and make both sides more even."
# Closeness: same mechanism (water crosses a semipermeable membrane low-solute ->
# high-solute to even out), plain + vivid (high). Runs longer -- : went ELI5 on a
# grade-school topic (register play, not a length win).
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

TARGET="Osmosis is when water moves through a thin barrier from the side with fewer dissolved things to the side with more, evening out the concentration on both sides."
EXPR=":'osmosis is the movement of water molecules across a semipermeable membrane from a region of lower solute concentration to a region of higher solute concentration'"

echo "TARGET (${#TARGET} chars): $TARGET"
echo "EXPR   (${#EXPR} chars): $EXPR"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
