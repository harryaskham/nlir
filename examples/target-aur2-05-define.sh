#!/usr/bin/env bash
# nlir TARGET-GOLF (aur-2 #05) — reverse game via : (simplify) on a bare TERM:
# the jargon word IS the seed; : expands it into a plain-language definition.
# Best compression in my >/: lane so far -- 13 chars regenerate an 82-char line.
#
# TARGET (82 chars):
#   "An idempotent operation gives the same result no matter how many times you run it."
#
# EXPRESSION (13 chars):
#   :'idempotent'
#
# Real output (claude-sonnet-5):
#   "Doing it again doesn't change anything after the first time."
# Closeness: same concept in plain speech (high); 84% shorter than the target.
# ":term" is the "explain this word simply" move for pi.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

TARGET="An idempotent operation gives the same result no matter how many times you run it."
EXPR=":'idempotent'"

echo "TARGET (${#TARGET} chars): $TARGET"
echo "EXPR   (${#EXPR} chars): $EXPR"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
