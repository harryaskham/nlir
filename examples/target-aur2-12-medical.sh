#!/usr/bin/env bash
# nlir TARGET-GOLF (aur-2 #12) — reverse game via : (simplify): MEDICAL jargon ->
# plain. The "explain my diagnosis in words I understand" move (aur-2 : lane).
#
# TARGET (105 chars):
#   "High blood pressure means your heart works too hard to pump blood, which can slowly damage your arteries."
#
# EXPRESSION (102 chars):
#   :'hypertension is chronically elevated arterial blood pressure that strains the cardiovascular system'
#
# Real output (claude-sonnet-5):
#   "High blood pressure is when the pressure inside your blood tubes stays too
#    high for a long time, which makes your heart and blood tubes work extra hard."
# Closeness: same meaning, plain register (high). : trades compression for clarity
# (medical jargon -> layperson), like the legalese/error entries.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

TARGET="High blood pressure means your heart works too hard to pump blood, which can slowly damage your arteries."
EXPR=":'hypertension is chronically elevated arterial blood pressure that strains the cardiovascular system'"

echo "TARGET (${#TARGET} chars): $TARGET"
echo "EXPR   (${#EXPR} chars): $EXPR"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
