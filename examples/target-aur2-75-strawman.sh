#!/usr/bin/env bash
# nlir TARGET-GOLF (aur-2 #75) — reverse game via : (simplify): LOGIC/RHETORIC jargon
# (a straw man) -> plain, ~even length.
#
# TARGET (~162 chars):
#   "A straw man is when you twist someone's argument into a weaker, sillier version
#    and then knock THAT down -- instead of actually responding to what they really said."
#
# EXPRESSION (164 chars):
#   :'a straw man is an informal fallacy where someone misrepresents their opponents argument to make it easier to attack rather than engaging with the actual position'
#
# Real output (claude-sonnet-5):
#   "A straw man is when someone doesn't listen carefully to what another person really
#    means. Instead, they pretend the person said something silly or wrong -- something
#    easier to argue against -- and then they attack that instead of the real idea."
# Closeness: same fallacy (misrepresent the argument as a weaker version, attack that
# not the real position), plain (high), ~even length. : drops "informal fallacy" for
# "when someone pretends you said something silly".
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

TARGET="A straw man is when you twist someone's argument into a weaker, sillier version and then knock THAT down -- instead of actually responding to what they really said."
EXPR=":'a straw man is an informal fallacy where someone misrepresents their opponents argument to make it easier to attack rather than engaging with the actual position'"

echo "TARGET (${#TARGET} chars): $TARGET"
echo "EXPR   (${#EXPR} chars): $EXPR"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
