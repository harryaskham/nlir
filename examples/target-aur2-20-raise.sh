#!/usr/bin/env bash
# nlir TARGET-GOLF (aur-2 #20) — reverse game via ~> (summary of expand): a
# practical how-to one-liner from a 28-char seed.
#
# TARGET (~114 chars):
#   "Research your market value, list your achievements, and confidently ask for a specific number at the right moment."
#
# EXPRESSION (28 chars):
#   ~>'how to negotiate a raise'
#
# Real output (claude-sonnet-5):
#   "Learn how to research fair pay, document your value, time it well, and
#    confidently negotiate a salary increase with your employer."
# Closeness: same advice (research pay, document value, time it, negotiate
# confidently), one dense sentence (high). 75% shorter; ~> works for how-to too.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

TARGET="Research your market value, list your achievements, and confidently ask for a specific number at the right moment."
EXPR="~>'how to negotiate a raise'"

echo "TARGET (${#TARGET} chars): $TARGET"
echo "EXPR   (${#EXPR} chars): $EXPR"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
