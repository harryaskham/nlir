#!/usr/bin/env bash
# nlir TARGET-GOLF (aur-2 #04) — reverse game via : (simplify): jargon -> plain.
#
# TARGET (68 chars) — how a non-technical user would phrase it:
#   "The website is down because too many people are visiting it at once."
#
# EXPRESSION (57 chars) — a jargon seed simplified by : :
#   :'the website returns 503 errors from a traffic overload'
#
# Real output (claude-sonnet-5):
#   "The website stopped working for a little while because too many people tried to visit it at the same time."
# Closeness: same meaning + plain register (high). : keeps length similar, so the
# win here is the jargon->plain TRANSLATION for a layperson, not raw compression.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

TARGET="The website is down because too many people are visiting it at once."
EXPR=":'the website returns 503 errors from a traffic overload'"

echo "TARGET (${#TARGET} chars): $TARGET"
echo "EXPR   (${#EXPR} chars): $EXPR"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
