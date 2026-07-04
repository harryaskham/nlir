#!/usr/bin/env bash
# nlir TARGET-GOLF (aur-2 #69) — reverse game via : (simplify): LEGAL jargon
# (double jeopardy) -> plain.
#
# TARGET (~132 chars):
#   "Double jeopardy is a rule that says once you've been found not guilty of a
#    crime, you can't be put on trial for that same crime again."
#
# EXPRESSION (126 chars):
#   :'double jeopardy is a legal rule that stops someone from being tried twice for the same crime after they have been acquitted'
#
# Real output (claude-sonnet-5):
#   "If someone goes to court for doing something wrong, and the judge or jury says
#    'you didn't do it,' then no one is allowed to put them on trial again for that
#    exact same thing. This rule is called double jeopardy."
# Closeness: same rule (acquitted -> can't be retried for the same crime), plain
# (high), ~even length. : renders "acquitted" as "the jury says you didn't do it".
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

TARGET="Double jeopardy is a rule that says once you've been found not guilty of a crime, you can't be put on trial for that same crime again."
EXPR=":'double jeopardy is a legal rule that stops someone from being tried twice for the same crime after they have been acquitted'"

echo "TARGET (${#TARGET} chars): $TARGET"
echo "EXPR   (${#EXPR} chars): $EXPR"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
