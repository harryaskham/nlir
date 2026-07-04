#!/usr/bin/env bash
# nlir TARGET-GOLF (aur-2 #15) — reverse game via : (simplify) as an ANALOGY
# engine on a bare CS term. 12 chars regenerate a full analogy-driven definition
# -- ties my tightest (cf. #05 idempotent 13c, #09 mutex).
#
# TARGET (~148 chars):
#   "Recursion is when something is defined in terms of itself, like a set of Russian nesting dolls where each doll contains a smaller version of itself."
#
# EXPRESSION (12 chars):
#   :'recursion'
#
# Real output (claude-sonnet-5):
#   "Recursion is when something does a job by doing a smaller version of that same
#    job inside itself... It's like standing between two mirrors and seeing the
#    same picture repeat smaller and smaller each time."
# Closeness: same concept + a concrete analogy (high) -- the model picks its own
# metaphor (two mirrors vs nesting dolls). : doesn't just define, it illustrates.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

TARGET="Recursion is when something is defined in terms of itself, like a set of Russian nesting dolls where each doll contains a smaller version of itself."
EXPR=":'recursion'"

echo "TARGET (${#TARGET} chars): $TARGET"
echo "EXPR   (${#EXPR} chars): $EXPR"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
