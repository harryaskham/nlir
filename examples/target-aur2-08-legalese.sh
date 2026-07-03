#!/usr/bin/env bash
# nlir TARGET-GOLF (aur-2 #08) — reverse game via : (simplify): LEGALESE -> plain.
# Complements define (#05): on a bare jargon TERM : compresses hugely; on a full
# legalese SENTENCE the win is CLARITY, not compression -- : untangles the legalese.
#
# TARGET (74 chars):
#   "You can cancel anytime and get a refund for the rest of your subscription."
#
# EXPRESSION (76 chars):
#   :'you may terminate the agreement at any time and receive a prorated refund'
#
# Real output (claude-sonnet-5):
#   "You can end the agreement whenever you want, and you'll get back the part of
#    the money you already paid for that you haven't used yet."
# Closeness: same meaning, plain register (high). : trades length for clarity here
# (~0 compression) -- the "translate this ToS / legalese for me" move in pi.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

TARGET="You can cancel anytime and get a refund for the rest of your subscription."
EXPR=":'you may terminate the agreement at any time and receive a prorated refund'"

echo "TARGET (${#TARGET} chars): $TARGET"
echo "EXPR   (${#EXPR} chars): $EXPR"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
