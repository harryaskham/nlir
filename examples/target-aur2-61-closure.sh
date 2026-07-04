#!/usr/bin/env bash
# nlir TARGET-GOLF (aur-2 #61) — reverse game via ~> (summary of expand): a dense
# TECHNICAL one-liner defining a programming concept from a 36-char seed.
#
# TARGET (~173 chars):
#   "A closure is a function that remembers the variables from the scope where it was
#    created, so it can still use them later even after that outer function has
#    finished running."
#
# EXPRESSION (36 chars):
#   ~>'what is a closure in programming'
#
# Real output (claude-sonnet-5):
#   "A closure is a function that retains access to the variables from its defining
#    scope even after that scope has finished executing, enabling uses like data
#    privacy, persistent state, and factory functions in languages such as JavaScript
#    and Python."
# Closeness: same core (a function that keeps its defining scope's variables alive),
# but ~> lands DEEP technical register (data privacy, factory functions, JS/Python)
# (high). 79% shorter. (For a plainer phrasing, use :~>.)
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

TARGET="A closure is a function that remembers the variables from the scope where it was created, so it can still use them later even after that outer function has finished running."
EXPR="~>'what is a closure in programming'"

echo "TARGET (${#TARGET} chars): $TARGET"
echo "EXPR   (${#EXPR} chars): $EXPR"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
