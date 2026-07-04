#!/usr/bin/env bash
# nlir TARGET-GOLF (aur-2 #14) — reverse game via : (simplify): FINANCIAL jargon
# -> plain. The "explain my money situation in plain terms" move (aur-2 : lane).
#
# TARGET (98 chars):
#   "You are paying less than the interest each month, so your debt keeps growing instead of shrinking."
#
# EXPRESSION (92 chars):
#   :'your minimum payment is below the accrued interest so the principal balance keeps growing'
#
# Real output (claude-sonnet-5):
#   "You're paying so little each month that it doesn't even cover the extra fee
#    (called interest) added to what you owe. So instead of shrinking, the amount
#    you owe just keeps getting bigger and bigger."
# Closeness: same meaning, plain register (high). : trades compression for clarity
# (finance jargon -> layperson), like the legalese/medical entries.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

TARGET="You are paying less than the interest each month, so your debt keeps growing instead of shrinking."
EXPR=":'your minimum payment is below the accrued interest so the principal balance keeps growing'"

echo "TARGET (${#TARGET} chars): $TARGET"
echo "EXPR   (${#EXPR} chars): $EXPR"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
