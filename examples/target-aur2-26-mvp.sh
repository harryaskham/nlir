#!/usr/bin/env bash
# nlir TARGET-GOLF (aur-2 #26) — reverse game via : (simplify) on a bare ACRONYM:
# 6 chars -> the concept in plain words. New tightest (cf. :'YAGNI' 8c, :'an API' 9c).
#
# TARGET (~117 chars):
#   "MVP means Minimum Viable Product: the simplest version you can ship to test whether an idea works before building more."
#
# EXPRESSION (6 chars):
#   :'MVP'
#
# Real output (claude-sonnet-5):
#   "The simplest version of something you build first, just to see if it works,
#    before you add all the fancy extra parts."
# Closeness: same concept (simplest first version to test an idea) in plain words
# (high). 95% shorter; the "explain this term" move, now at 6 chars.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

TARGET="MVP means Minimum Viable Product: the simplest version you can ship to test whether an idea works before building more."
EXPR=":'MVP'"

echo "TARGET (${#TARGET} chars): $TARGET"
echo "EXPR   (${#EXPR} chars): $EXPR"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
