#!/usr/bin/env bash
# nlir TARGET-GOLF (aur-2 #24) — reverse game via : (simplify) as an ANALOGY
# engine on a bare term: 12 chars -> a full analogy-driven definition.
#
# TARGET (~144 chars):
#   "A webhook is like a doorbell for apps: instead of you constantly checking for updates, the other service rings you the moment something happens."
#
# EXPRESSION (12 chars):
#   :'a webhook'
#
# Real output (claude-sonnet-5):
#   "A webhook is like a note you leave for a computer program: 'when something
#    happens, send me a message right away.' So instead of you constantly checking
#    for news, the program tells you the moment something new happens."
# Closeness: same concept (no polling -> get notified on events), plain + its own
# analogy (note vs doorbell) (high). 92% shorter.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

TARGET="A webhook is like a doorbell for apps: instead of you constantly checking for updates, the other service rings you the moment something happens."
EXPR=":'a webhook'"

echo "TARGET (${#TARGET} chars): $TARGET"
echo "EXPR   (${#EXPR} chars): $EXPR"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
