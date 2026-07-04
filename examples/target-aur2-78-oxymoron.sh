#!/usr/bin/env bash
# nlir TARGET-GOLF (aur-2 #78) — reverse game via : (simplify): LINGUISTICS jargon
# (an oxymoron) -> plain, ~even length; : keeps the examples and explains them.
#
# TARGET (~162 chars):
#   "An oxymoron is when you put two words that seem to contradict each other right
#    next to each other on purpose -- like deafening silence or bittersweet -- for effect."
#
# EXPRESSION (156 chars):
#   :'an oxymoron is a figure of speech in which two contradictory terms appear together to create a rhetorical effect such as deafening silence or bittersweet'
#
# Real output (claude-sonnet-5):
#   "An oxymoron is when you put two words together that seem to mean opposite things,
#    but they still make sense in a fun way. Like 'deafening silence' -- silence isn't
#    loud, but it can feel really strong and quiet at once. Or 'bittersweet' -- something
#    that's a little sad and a little happy at the same time."
# Closeness: same idea (two contradictory words placed together on purpose), same
# examples (deafening silence / bittersweet), plain (high). : drops "figure of speech /
# rhetorical effect" and unpacks each example instead.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

TARGET="An oxymoron is when you put two words that seem to contradict each other right next to each other on purpose -- like deafening silence or bittersweet -- for effect."
EXPR=":'an oxymoron is a figure of speech in which two contradictory terms appear together to create a rhetorical effect such as deafening silence or bittersweet'"

echo "TARGET (${#TARGET} chars): $TARGET"
echo "EXPR   (${#EXPR} chars): $EXPR"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
