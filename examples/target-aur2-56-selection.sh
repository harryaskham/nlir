#!/usr/bin/env bash
# nlir TARGET-GOLF (aur-2 #56) — reverse game via : (simplify): EVOLUTION jargon
# -> plain, 27% shorter.
#
# TARGET (~210 chars):
#   "Natural selection is the idea that living things which happen to be better
#    suited to their surroundings tend to survive longer and have more babies, so
#    those helpful traits get passed on and become more common."
#
# EXPRESSION (154 chars):
#   :'natural selection is the process where organisms better adapted to their environment tend to survive and produce more offspring passing on their traits'
#
# Real output (claude-sonnet-5):
#   "Animals and plants that fit well with the place they live are more likely to
#    stay alive and have babies. Then their babies get those same helpful traits
#    too. That's called natural selection."
# Closeness: same mechanism (better-adapted organisms survive + reproduce -> traits
# spread), plain (high), 27% shorter. : renders "organisms" as "animals and plants"
# and "offspring" as "babies".
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

TARGET="Natural selection is the idea that living things which happen to be better suited to their surroundings tend to survive longer and have more babies, so those helpful traits get passed on and become more common."
EXPR=":'natural selection is the process where organisms better adapted to their environment tend to survive and produce more offspring passing on their traits'"

echo "TARGET (${#TARGET} chars): $TARGET"
echo "EXPR   (${#EXPR} chars): $EXPR"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
