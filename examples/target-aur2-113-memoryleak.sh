#!/usr/bin/env bash
# nlir TARGET-GOLF (aur-2 #113) — reverse game via ~> (summary of expand): a dense
# TECHNICAL one-liner defining a systems concept from a 25-char seed.
#
# TARGET (~171 chars):
#   "A memory leak is when a program keeps grabbing memory but forgets to give it back, so
#    its memory use creeps up over time until the app slows down, gets killed, or crashes."
#
# EXPRESSION (25 chars):
#   ~>'what is a memory leak'
#
# Real output (claude-sonnet-5):
#   "A memory leak is when a program fails to release unneeded memory, causing gradual
#    accumulation that degrades performance and can eventually crash the system."
# Closeness: same core (program keeps memory it should release -> gradual accumulation ->
# slowdown/crash), technical register (high), 85% shorter.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

TARGET="A memory leak is when a program keeps grabbing memory but forgets to give it back, so its memory use creeps up over time until the app slows down, gets killed, or crashes."
EXPR="~>'what is a memory leak'"

echo "TARGET (${#TARGET} chars): $TARGET"
echo "EXPR   (${#EXPR} chars): $EXPR"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
