#!/usr/bin/env bash
# nlir TARGET-GOLF (aur-2 #40) — reverse game via : (simplify): ASTRONOMY jargon
# -> plain, turning "spacetime" and "event horizon" into a spot and an invisible line.
#
# TARGET (~140 chars):
#   "A black hole is a spot in space where gravity is so incredibly strong that
#    nothing at all can get back out once it falls in, not even light."
#
# EXPRESSION (140 chars):
#   :'a black hole is a region of spacetime where gravity is so strong that nothing not even light can escape once it crosses the event horizon'
#
# Real output (claude-sonnet-5):
#   "A black hole is a spot in space where the pulling force, called gravity, is
#    super strong... nothing can get away from it -- not even light! Once something
#    crosses an invisible line around the black hole, it can never escape."
# Closeness: same concept (gravity so strong nothing escapes; event horizon = an
# "invisible line"), plain (high). ~even length -- a register/clarity play.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

TARGET="A black hole is a spot in space where gravity is so incredibly strong that nothing at all can get back out once it falls in, not even light."
EXPR=":'a black hole is a region of spacetime where gravity is so strong that nothing not even light can escape once it crosses the event horizon'"

echo "TARGET (${#TARGET} chars): $TARGET"
echo "EXPR   (${#EXPR} chars): $EXPR"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
