#!/usr/bin/env bash
# nlir TARGET-GOLF (aur-2 #30) — reverse game via : (simplify) as an ANALOGY
# engine on a bare term: 26 chars -> a plain, analogy-driven definition.
#
# TARGET (~140 chars):
#   "A software container is like a shipping container for code: it packs an app with everything it needs so it runs the same way on any machine."
#
# EXPRESSION (26 chars):
#   :'a container in software'
#
# Real output (claude-sonnet-5):
#   "A container is like a special box for a computer program. It holds everything
#    the program needs to run... so it can run the same way no matter what computer
#    it's on, just like a lunchbox has everything you need wherever you take it."
# Closeness: same concept (packs everything -> runs anywhere), plain + its own
# analogy (box/lunchbox vs shipping container) (high). 81% shorter.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

TARGET="A software container is like a shipping container for code: it packs an app with everything it needs so it runs the same way on any machine."
EXPR=":'a container in software'"

echo "TARGET (${#TARGET} chars): $TARGET"
echo "EXPR   (${#EXPR} chars): $EXPR"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
