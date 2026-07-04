#!/usr/bin/env bash
# nlir TARGET-GOLF (aur-2 #54) — reverse game via : (simplify): MATH jargon -> plain,
# a 30% compression win.
#
# TARGET (~146 chars):
#   "A prime number is a whole number bigger than 1 that you cannot split evenly into
#    a product of smaller numbers -- its only factors are 1 and itself."
#
# EXPRESSION (102 chars):
#   :'a prime number is a whole number greater than one that can only be divided evenly by one and itself'
#
# Real output (claude-sonnet-5):
#   "A prime number is a number bigger than 1 that can only be split evenly by 1 and
#    itself."
# Closeness: same definition (a whole number > 1 divisible only by 1 and itself),
# plain (high), 30% shorter. : drops "factors" for "split evenly".
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

TARGET="A prime number is a whole number bigger than 1 that you cannot split evenly into a product of smaller numbers -- its only factors are 1 and itself."
EXPR=":'a prime number is a whole number greater than one that can only be divided evenly by one and itself'"

echo "TARGET (${#TARGET} chars): $TARGET"
echo "EXPR   (${#EXPR} chars): $EXPR"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
