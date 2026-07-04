#!/usr/bin/env bash
# nlir TARGET-GOLF (aur-2 #09) — reverse game via : (simplify) as an ANALOGY
# engine: a plain technical seed comes back as an everyday analogy. (aur-1 handed
# metaphor/analogy to the : lane -- so it's aur-2's.)
#
# TARGET (118 chars):
#   "A mutex is like a single bathroom key: only one person can hold it at a time, so everyone else has to wait their turn."
#
# EXPRESSION (53 chars):
#   :'a mutex is a lock only one thread can hold at once'
#
# Real output (claude-sonnet-5):
#   "A mutex is like a key. Only one helper can hold the key at a time, so only
#    one helper can do the special job while everyone else waits their turn."
# Closeness: same analogy (a key; one holder; others wait), plain register (high);
# 55% shorter. : doesn't just define -- it reaches for a concrete metaphor. The
# "ELI5 with an analogy" move for pi.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

TARGET="A mutex is like a single bathroom key: only one person can hold it at a time, so everyone else has to wait their turn."
EXPR=":'a mutex is a lock only one thread can hold at once'"

echo "TARGET (${#TARGET} chars): $TARGET"
echo "EXPR   (${#EXPR} chars): $EXPR"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
