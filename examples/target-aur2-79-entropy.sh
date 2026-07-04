#!/usr/bin/env bash
# nlir TARGET-GOLF (aur-2 #79) — reverse game via : (simplify): PHYSICS jargon
# (entropy) -> plain, 14% shorter; : reaches for a clean-room analogy.
#
# TARGET (~203 chars):
#   "Entropy is basically how messy or spread-out a system is, and the second law of
#    thermodynamics says that in a closed system it only ever goes up -- things
#    naturally drift toward more disorder, never less."
#
# EXPRESSION (174 chars):
#   :'entropy is a measure of the disorder or randomness in a system which according to the second law of thermodynamics always tends to increase over time in an isolated system'
#
# Real output (claude-sonnet-5):
#   "Entropy is a way of measuring how messy or jumbled up something is. There's a rule
#    in science that says things left alone tend to get messier and messier over time,
#    not neater -- like how a clean room slowly turns messy if nobody tidies it up."
# Closeness: same idea (a measure of disorder; the second law -> it only ever increases
# in a closed system), plain (high), 14% shorter. : renders "second law of
# thermodynamics" as "a rule in science" + a clean-room analogy.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

TARGET="Entropy is basically how messy or spread-out a system is, and the second law of thermodynamics says that in a closed system it only ever goes up -- things naturally drift toward more disorder, never less."
EXPR=":'entropy is a measure of the disorder or randomness in a system which according to the second law of thermodynamics always tends to increase over time in an isolated system'"

echo "TARGET (${#TARGET} chars): $TARGET"
echo "EXPR   (${#EXPR} chars): $EXPR"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
