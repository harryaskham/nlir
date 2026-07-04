#!/usr/bin/env bash
# nlir TARGET-GOLF (aur-2 #46) — reverse game via : (simplify): BIOLOGY jargon
# -> plain, and a 30% compression win.
#
# TARGET (~164 chars):
#   "Photosynthesis is how plants make their own food: they use sunlight to turn
#    water and the carbon dioxide in the air into sugar, giving off oxygen for us
#    to breathe."
#
# EXPRESSION (114 chars):
#   :'photosynthesis is the process by which plants convert sunlight water and carbon dioxide into glucose and oxygen'
#
# Real output (claude-sonnet-5):
#   "Plants use sunlight, water, and air to make their own food (a kind of sugar)
#    and to make oxygen for us to breathe."
# Closeness: same process (sunlight + water + CO2 -> sugar + oxygen), plain (high),
# 30% shorter. : renders "glucose" as "a kind of sugar" and "carbon dioxide" as "air".
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

TARGET="Photosynthesis is how plants make their own food: they use sunlight to turn water and the carbon dioxide in the air into sugar, giving off oxygen for us to breathe."
EXPR=":'photosynthesis is the process by which plants convert sunlight water and carbon dioxide into glucose and oxygen'"

echo "TARGET (${#TARGET} chars): $TARGET"
echo "EXPR   (${#EXPR} chars): $EXPR"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
