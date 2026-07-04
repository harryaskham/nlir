#!/usr/bin/env bash
# nlir TARGET-GOLF (aur-2 #21) — reverse game via : (simplify) as an ANALOGY
# engine on a bare term. NINE chars regenerate a full analogy-driven definition
# -- my tightest yet (cf. #05 idempotent 13c, #15 recursion 12c).
#
# TARGET (~143 chars):
#   "An API is a set of rules that lets two programs talk to each other, like a waiter taking your order to the kitchen and bringing back your food."
#
# EXPRESSION (9 chars):
#   :'an API'
#
# Real output (claude-sonnet-5):
#   "a helper that lets two computer programs talk to each other, like a messenger
#    passing notes back and forth"
# Closeness: same concept + a concrete analogy (high) -- the model picks its own
# metaphor (messenger vs waiter). 94% shorter. : illustrates, it doesn't just define.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

TARGET="An API is a set of rules that lets two programs talk to each other, like a waiter taking your order to the kitchen and bringing back your food."
EXPR=":'an API'"

echo "TARGET (${#TARGET} chars): $TARGET"
echo "EXPR   (${#EXPR} chars): $EXPR"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
