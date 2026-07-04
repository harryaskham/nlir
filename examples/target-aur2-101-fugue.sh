#!/usr/bin/env bash
# nlir TARGET-GOLF (aur-2 #101) — reverse game via : (simplify): MUSIC jargon
# (a fugue) -> plain, 11% shorter.
#
# TARGET (~191 chars):
#   "A fugue is a piece of music where one voice starts a short tune, and then other
#    voices come in one by one playing the same tune, overlapping so it weaves together
#    into a rich layered texture."
#
# EXPRESSION (170 chars):
#   :'a fugue is a musical composition in which a short melody or theme is introduced by one voice and then repeated and interwoven by other voices in overlapping succession'
#
# Real output (claude-sonnet-5):
#   "A fugue is a piece of music where one voice or instrument plays a short, catchy
#    tune first. Then, other voices or instruments join in one by one, each playing that
#    same tune, so they all overlap and mix together like a fun musical puzzle."
# Closeness: same idea (one voice introduces a short theme, others repeat + interweave
# it in overlapping succession), plain (high), 11% shorter.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

TARGET="A fugue is a piece of music where one voice starts a short tune, and then other voices come in one by one playing the same tune, overlapping so it weaves together into a rich layered texture."
EXPR=":'a fugue is a musical composition in which a short melody or theme is introduced by one voice and then repeated and interwoven by other voices in overlapping succession'"

echo "TARGET (${#TARGET} chars): $TARGET"
echo "EXPR   (${#EXPR} chars): $EXPR"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
