#!/usr/bin/env bash
# nlir TARGET-GOLF (aur-2 #06) — reverse game via : (simplify) on a full jargon
# SENTENCE (vs last tick's bare term): a technical instruction -> layperson version.
#
# TARGET (86 chars):
#   "When you make a change, save a snapshot so you can go back to it later if you need to."
#
# EXPRESSION (73 chars):
#   :'commit your changes to version control so you can revert to them later'
#
# Real output (claude-sonnet-5):
#   "Save your changes so you can go back to them later if you need to."
# Closeness: same meaning + plain register, very close phrasing (high). : strips
# the jargon (commit / version control / revert) while keeping the instruction intact.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

TARGET="When you make a change, save a snapshot so you can go back to it later if you need to."
EXPR=":'commit your changes to version control so you can revert to them later'"

echo "TARGET (${#TARGET} chars): $TARGET"
echo "EXPR   (${#EXPR} chars): $EXPR"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
