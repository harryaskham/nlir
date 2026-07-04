#!/usr/bin/env bash
# nlir TARGET-GOLF (aur-2 #25) — reverse game via : (simplify) on a bare ACRONYM:
# 8 chars -> the principle in plain words. My tightest yet (cf. :'an API' 9c).
#
# TARGET (~152 chars):
#   "YAGNI stands for You Aren't Gonna Need It: don't build a feature until you actually need it, to avoid wasting effort on things that may never be used."
#
# EXPRESSION (8 chars):
#   :'YAGNI'
#
# Real output (claude-sonnet-5):
#   "Don't build something now just because you might need it later — wait until you
#    actually need it, then build it."
# Closeness: same principle in plain words (high). : gives the MEANING (not the
# letter expansion) -- the "what does this dev acronym mean" move. 95% shorter.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

TARGET="YAGNI stands for You Aren't Gonna Need It: don't build a feature until you actually need it, to avoid wasting effort on things that may never be used."
EXPR=":'YAGNI'"

echo "TARGET (${#TARGET} chars): $TARGET"
echo "EXPR   (${#EXPR} chars): $EXPR"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
