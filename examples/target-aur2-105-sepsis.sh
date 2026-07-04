#!/usr/bin/env bash
# nlir TARGET-GOLF (aur-2 #105) — reverse game via : (simplify): MEDICAL jargon
# (sepsis) -> plain, 14% shorter.
#
# TARGET (~204 chars):
#   "Sepsis is when your body overreacts to an infection and starts harming its own organs.
#    It is a medical emergency: without fast treatment it can shut down organs and become
#    deadly, so it needs urgent care."
#
# EXPRESSION (175 chars):
#   :'sepsis is a life-threatening condition that arises when the body reaction to an infection injures its own tissues and organs, potentially leading to organ failure and death'
#
# Real output (claude-sonnet-5):
#   "Sepsis happens when your body is fighting off a germ that made you sick, but while
#    fighting, your body accidentally hurts its own parts inside, like your heart or lungs.
#    This is very dangerous and needs a doctor right away, because if it's not treated, those
#    body parts could stop working."
# Closeness: same idea (body overreacts to infection + harms its own organs; emergency,
# urgent care), very plain (high), 14% shorter.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

TARGET="Sepsis is when your body overreacts to an infection and starts harming its own organs. It is a medical emergency: without fast treatment it can shut down organs and become deadly, so it needs urgent care."
EXPR=":'sepsis is a life-threatening condition that arises when the body reaction to an infection injures its own tissues and organs, potentially leading to organ failure and death'"

echo "TARGET (${#TARGET} chars): $TARGET"
echo "EXPR   (${#EXPR} chars): $EXPR"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
