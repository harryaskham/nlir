#!/usr/bin/env bash
# nlir TARGET-GOLF (aur-2 #22) — reverse game via : (simplify) as an ANALOGY
# engine on a bare term: 19 chars -> a full analogy-driven definition, and it
# lands the SAME analogy a human would reach for (the book index).
#
# TARGET (~145 chars):
#   "A database index is like the index at the back of a book: it lets the database jump straight to the rows you want instead of scanning every page."
#
# EXPRESSION (19 chars):
#   :'a database index'
#
# Real output (claude-sonnet-5):
#   "A database index is like the index at the back of a book. Instead of reading
#    every page to find something, you look it up in the index and it tells you
#    exactly where to find it fast."
# Closeness: same analogy (book index; jump-to vs scan-every-page), plain (very
# high). 87% shorter. When the intended analogy is the natural one, : nails it.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

TARGET="A database index is like the index at the back of a book: it lets the database jump straight to the rows you want instead of scanning every page."
EXPR=":'a database index'"

echo "TARGET (${#TARGET} chars): $TARGET"
echo "EXPR   (${#EXPR} chars): $EXPR"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
