#!/usr/bin/env bash
# nlir TARGET-GOLF (aur-2 #47) — reverse game via : (simplify): FOOD-SCIENCE jargon
# -> plain. Honest note: on an approachable topic : reaches for a very kid-friendly
# register and OVERSHOOTS the target's length (an ELI5-lean, not a compression win).
#
# TARGET (~162 chars):
#   "The Maillard reaction is what happens when you sear or toast food: the heat
#    makes its proteins and sugars react and turn brown, creating that rich,
#    savory flavor."
#
# EXPRESSION (165 chars):
#   :'the Maillard reaction is a chemical reaction between amino acids and reducing sugars that gives browned food its distinctive flavor and occurs when food is heated'
#
# Real output (claude-sonnet-5):
#   "When you cook food and it turns brown -- like toast or a seared burger -- that's
#    ... the Maillard reaction. It's when tiny building blocks in food (from proteins
#    and sugars) get hot together and change into yummy new flavors and a brown
#    color. That's why cooked food often tastes so much better than raw food!"
# Closeness: same concept (heat -> proteins+sugars react -> brown + flavour), plain
# (high on meaning), but : expanded into a longer ELI5 explanation than the target.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

TARGET="The Maillard reaction is what happens when you sear or toast food: the heat makes its proteins and sugars react and turn brown, creating that rich, savory flavor."
EXPR=":'the Maillard reaction is a chemical reaction between amino acids and reducing sugars that gives browned food its distinctive flavor and occurs when food is heated'"

echo "TARGET (${#TARGET} chars): $TARGET"
echo "EXPR   (${#EXPR} chars): $EXPR"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
