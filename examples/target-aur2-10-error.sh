#!/usr/bin/env bash
# nlir TARGET-GOLF (aur-2 #10) — reverse game via : (simplify): a raw ERROR
# MESSAGE -> a friendly, user-facing one. The "turn this stack-trace-speak into
# something I can show a user" move (aur-2 : lane).
#
# TARGET (76 chars):
#   "The app cannot reach the internet right now — check your wifi and try again."
#
# EXPRESSION (74 chars):
#   :'the request failed with a network timeout; check connectivity and retry'
#
# Real output (claude-sonnet-5):
#   "The internet took too long to answer. Check that you're connected to the
#    internet, then try again."
# Closeness: same meaning + friendly register (high). Like the jargon/legalese
# entries, : trades compression for CLARITY here -- dev error -> human message.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

TARGET="The app cannot reach the internet right now — check your wifi and try again."
EXPR=":'the request failed with a network timeout; check connectivity and retry'"

echo "TARGET (${#TARGET} chars): $TARGET"
echo "EXPR   (${#EXPR} chars): $EXPR"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
