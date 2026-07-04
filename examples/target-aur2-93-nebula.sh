#!/usr/bin/env bash
# nlir TARGET-GOLF (aur-2 #93) — reverse game via : (simplify): ASTRONOMY jargon
# (a nebula) -> plain, 29% shorter.
#
# TARGET (~175 chars):
#   "A nebula is a huge cloud of gas and dust floating in space -- some are stellar
#    nurseries where new stars form, and others are the glowing wreckage left behind
#    when a star dies."
#
# EXPRESSION (125 chars):
#   :'a nebula is a giant cloud of gas and dust in space where new stars are often born or which is left behind when a star dies'
#
# Real output (claude-sonnet-5):
#   "A nebula is a huge cloud of gas and dust way out in space. Sometimes new stars are
#    made inside these clouds. Other times, the cloud is what's left over after a star
#    dies."
# Closeness: same idea (a giant gas/dust cloud that is either a stellar nursery or a
# dead-star remnant), plain (high), 29% shorter.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

TARGET="A nebula is a huge cloud of gas and dust floating in space -- some are stellar nurseries where new stars form, and others are the glowing wreckage left behind when a star dies."
EXPR=":'a nebula is a giant cloud of gas and dust in space where new stars are often born or which is left behind when a star dies'"

echo "TARGET (${#TARGET} chars): $TARGET"
echo "EXPR   (${#EXPR} chars): $EXPR"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
