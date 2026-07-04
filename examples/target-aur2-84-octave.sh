#!/usr/bin/env bash
# nlir TARGET-GOLF (aur-2 #84) — reverse game via : (simplify): MUSIC-THEORY jargon
# (an octave) -> plain, 21% shorter.
#
# TARGET (~188 chars):
#   "An octave is the gap between one note and another that vibrates twice as fast --
#    they sound like the same note, just higher or lower, which is why a low C and a
#    high C feel like the same C."
#
# EXPRESSION (149 chars):
#   :'an octave is the interval between one musical pitch and another with double its frequency which the ear perceives as the same note higher or lower'
#
# Real output (claude-sonnet-5):
#   "An octave is when a musical note plays twice as fast and sounds higher, or half as
#    fast and sounds lower -- but your ears hear it as the same note, just higher or
#    lower up."
# Closeness: same idea (double the frequency -> the same note an octave higher; the ear
# hears it as the same note), plain (high), 21% shorter.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

TARGET="An octave is the gap between one note and another that vibrates twice as fast -- they sound like the same note, just higher or lower, which is why a low C and a high C feel like the same C."
EXPR=":'an octave is the interval between one musical pitch and another with double its frequency which the ear perceives as the same note higher or lower'"

echo "TARGET (${#TARGET} chars): $TARGET"
echo "EXPR   (${#EXPR} chars): $EXPR"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
