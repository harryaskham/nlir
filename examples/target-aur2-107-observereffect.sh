#!/usr/bin/env bash
# nlir TARGET-GOLF (aur-2 #107) — reverse game via : (simplify): PHYSICS jargon
# (the observer effect) -> plain, 13% shorter.
#
# TARGET (~193 chars):
#   "The observer effect is the idea that just measuring something can change it: the act
#    of looking disturbs the thing you are trying to look at, so you never quite catch it in
#    its untouched state."
#
# EXPRESSION (167 chars):
#   :'the observer effect refers to the phenomenon where the mere act of observing or measuring a system inevitably disturbs it, altering the very quantity being measured'
#
# Real output (claude-sonnet-5):
#   "Just looking at something or checking on it can sometimes change it a little bit --
#    simply because you looked. This is called the observer effect: the act of watching or
#    measuring something can bump it or change it, so you're not seeing it exactly as it was
#    before you looked."
# Closeness: same idea (measuring/looking disturbs the thing; never seen untouched), plain
# (high), 13% shorter.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

TARGET="The observer effect is the idea that just measuring something can change it: the act of looking disturbs the thing you are trying to look at, so you never quite catch it in its untouched state."
EXPR=":'the observer effect refers to the phenomenon where the mere act of observing or measuring a system inevitably disturbs it, altering the very quantity being measured'"

echo "TARGET (${#TARGET} chars): $TARGET"
echo "EXPR   (${#EXPR} chars): $EXPR"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
