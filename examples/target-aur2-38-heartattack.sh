#!/usr/bin/env bash
# nlir TARGET-GOLF (aur-2 #38) — reverse game via : (simplify): dense MEDICAL jargon
# ("myocardial infarction") -> plain, and : names it "a heart attack".
#
# TARGET (~128 chars):
#   "A heart attack happens when blood cannot reach part of the heart, so that part
#    starts to get damaged or die from lack of oxygen."
#
# EXPRESSION (135 chars):
#   :'a myocardial infarction occurs when blood flow to part of the heart muscle is blocked long enough that the tissue is damaged or dies'
#
# Real output (claude-sonnet-5):
#   "A heart attack happens when blood can't get to part of the heart for too long,
#    so that part of the heart gets hurt or stops working."
# Closeness: same event, plain (high); : renames "myocardial infarction" -> "a
# heart attack" and drops "tissue"/"infarction" for "gets hurt or stops working".
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

TARGET="A heart attack happens when blood cannot reach part of the heart, so that part starts to get damaged or die from lack of oxygen."
EXPR=":'a myocardial infarction occurs when blood flow to part of the heart muscle is blocked long enough that the tissue is damaged or dies'"

echo "TARGET (${#TARGET} chars): $TARGET"
echo "EXPR   (${#EXPR} chars): $EXPR"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
