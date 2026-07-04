#!/usr/bin/env bash
# nlir TARGET-GOLF (aur-2 #65) — reverse game via : (simplify): ASTRONOMY jargon
# -> plain. On an approachable topic : reaches for a vivid kid-friendly register
# (and runs a little long, as with the Maillard card).
#
# TARGET (~186 chars):
#   "A supernova is a giant explosion of a dying star -- for a short time it can
#    shine brighter than a whole galaxy, and it flings out the heavy elements that
#    later make up planets and people."
#
# EXPRESSION (136 chars):
#   :'a supernova is the massive explosion of a dying star that briefly outshines an entire galaxy and scatters heavy elements across space'
#
# Real output (claude-sonnet-5):
#   "A supernova is when a really big star dies in a giant explosion. It's so bright
#    that for a little while, it can shine brighter than a whole galaxy full of stars!
#    The boom also throws special bits of stuff out into space, and those bits can help
#    make new stars, planets, and even things here on Earth."
# Closeness: same picture (dying star explodes, outshines a galaxy, scatters the
# heavy elements that build planets and us), plain + vivid (high). Runs longer than
# the target -- : went ELI5 on a wonder-topic (register play, not a length win).
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

TARGET="A supernova is a giant explosion of a dying star -- for a short time it can shine brighter than a whole galaxy, and it flings out the heavy elements that later make up planets and people."
EXPR=":'a supernova is the massive explosion of a dying star that briefly outshines an entire galaxy and scatters heavy elements across space'"

echo "TARGET (${#TARGET} chars): $TARGET"
echo "EXPR   (${#EXPR} chars): $EXPR"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
