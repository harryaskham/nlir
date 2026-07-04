#!/usr/bin/env bash
# nlir TARGET-GOLF (aur-2 #81) — reverse game via : (simplify): PHYSIOLOGY jargon
# (homeostasis) -> plain, ~even length.
#
# TARGET (~153 chars):
#   "Homeostasis is how your body keeps its inside conditions -- like temperature and
#    blood sugar -- steady and balanced, even when things outside are changing."
#
# EXPRESSION (158 chars):
#   :'homeostasis is the ability of the body to maintain a stable internal environment such as temperature and blood sugar despite changes in external conditions'
#
# Real output (claude-sonnet-5):
#   "Your body has a special way to keep things steady inside, like how warm it is or
#    how much sugar is in your blood -- even when things change outside, like hot or
#    cold weather. This is called homeostasis."
# Closeness: same idea (the body holds internal conditions -- temperature, blood sugar
# -- steady despite outside changes), plain (high), ~even length.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

TARGET="Homeostasis is how your body keeps its inside conditions -- like temperature and blood sugar -- steady and balanced, even when things outside are changing."
EXPR=":'homeostasis is the ability of the body to maintain a stable internal environment such as temperature and blood sugar despite changes in external conditions'"

echo "TARGET (${#TARGET} chars): $TARGET"
echo "EXPR   (${#EXPR} chars): $EXPR"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
