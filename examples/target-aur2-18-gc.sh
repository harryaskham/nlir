#!/usr/bin/env bash
# nlir TARGET-GOLF (aur-2 #18) — reverse game via : (simplify) as an ANALOGY
# engine on a bare CS term: 21 chars -> a plain, analogy-driven definition.
#
# TARGET (~137 chars):
#   "Garbage collection is when a program automatically finds and clears out memory it no longer needs, so you do not have to free it by hand."
#
# EXPRESSION (21 chars):
#   :'garbage collection'
#
# Real output (claude-sonnet-5):
#   "A computer's helper that cleans up bits of information the computer isn't
#    using anymore, so there's room for new stuff — kind of like tidying away toys
#    you're done playing with."
# Closeness: same concept + a concrete analogy (high); 85% shorter. : reaches for
# a metaphor (tidying toys) rather than a dry definition.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

TARGET="Garbage collection is when a program automatically finds and clears out memory it no longer needs, so you do not have to free it by hand."
EXPR=":'garbage collection'"

echo "TARGET (${#TARGET} chars): $TARGET"
echo "EXPR   (${#EXPR} chars): $EXPR"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
