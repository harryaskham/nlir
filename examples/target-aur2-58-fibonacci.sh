#!/usr/bin/env bash
# nlir TARGET-GOLF (aur-2 #58) — reverse game via : (simplify): MATH jargon
# (the Fibonacci sequence) -> plain, 22% shorter.
#
# TARGET (~161 chars):
#   "The Fibonacci sequence is a list of numbers that starts 0, 1, and then every
#    next number is just the previous two added together: 0, 1, 1, 2, 3, 5, 8, and
#    so on."
#
# EXPRESSION (125 chars):
#   :'the Fibonacci sequence is a series of numbers where each number is the sum of the two before it starting from zero and one'
#
# Real output (claude-sonnet-5):
#   "The Fibonacci sequence is a list of numbers. You start with 0 and 1. Then, to
#    get the next number, you just add the last two numbers together. You keep doing
#    that to make the whole list."
# Closeness: same rule (start 0,1; each = sum of the previous two), plain (high),
# 22% shorter. : states the recurrence as a plain step-by-step recipe.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

TARGET="The Fibonacci sequence is a list of numbers that starts 0, 1, and then every next number is just the previous two added together: 0, 1, 1, 2, 3, 5, 8, and so on."
EXPR=":'the Fibonacci sequence is a series of numbers where each number is the sum of the two before it starting from zero and one'"

echo "TARGET (${#TARGET} chars): $TARGET"
echo "EXPR   (${#EXPR} chars): $EXPR"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
