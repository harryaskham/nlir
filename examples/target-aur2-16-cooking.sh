#!/usr/bin/env bash
# nlir TARGET-GOLF (aur-2 #16) — reverse game via : (simplify): CULINARY jargon
# -> plain. The "what does this recipe actually mean" move (aur-2 : lane).
#
# TARGET (87 chars):
#   "Cook the sauce gently on low heat until it thickens enough to coat the back of a spoon."
#
# EXPRESSION (68 chars):
#   :'reduce the sauce over low heat until it reaches nappe consistency'
#
# Real output (claude-sonnet-5):
#   "Cook the sauce on low heat until it gets a little thick — thick enough to
#    coat the back of a spoon."
# Closeness: same instruction, plain register (high) -- : unpacks "nappe" into
# "coat the back of a spoon". Chef-speak -> home-cook English.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

TARGET="Cook the sauce gently on low heat until it thickens enough to coat the back of a spoon."
EXPR=":'reduce the sauce over low heat until it reaches nappe consistency'"

echo "TARGET (${#TARGET} chars): $TARGET"
echo "EXPR   (${#EXPR} chars): $EXPR"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
