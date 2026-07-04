#!/usr/bin/env bash
# nlir TARGET-GOLF (aur-2 #17) — reverse game via ~> (summary of expand): a
# non-technical, everyday science one-liner (the ~> definer works across domains).
#
# TARGET (~115 chars):
#   "A rainbow appears when sunlight passes through raindrops, which bend and split the light into its different colors."
#
# EXPRESSION (25 chars):
#   ~>'what causes a rainbow'
#
# Real output (claude-sonnet-5):
#   "Rainbows form when sunlight refracts, internally reflects, and disperses into
#    its component colors as it passes through airborne water droplets, producing a
#    colorful arc in the sky."
# Closeness: same concept (sunlight through droplets -> split colors), one dense
# sentence (high). 78% shorter; ~> holds up outside tech, on plain science too.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

TARGET="A rainbow appears when sunlight passes through raindrops, which bend and split the light into its different colors."
EXPR="~>'what causes a rainbow'"

echo "TARGET (${#TARGET} chars): $TARGET"
echo "EXPR   (${#EXPR} chars): $EXPR"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
