#!/usr/bin/env bash
# nlir TARGET-GOLF (aur-2 #35) — reverse game via : (simplify): MUSIC-THEORY jargon
# -> plain, with : turning the "1st/3rd/5th of the scale" rule into "skip one".
#
# TARGET (~138 chars):
#   "A chord is a few notes played at the same time; a major chord is the
#    happy-sounding one built from the 1st, 3rd, and 5th notes of a scale."
#
# EXPRESSION (96 chars):
#   :'a major chord is three notes played together using the first third and fifth notes of a scale'
#
# Real output (claude-sonnet-5):
#   "A chord is when you play three notes at the same time and they sound nice
#    together. To make one, you pick a note, then skip one and pick the next, then
#    skip one more and pick the next after that."
# Closeness: same idea (three simultaneous notes; the 1-3-5 pattern rephrased as
# "skip one") in plain terms (high). 30% shorter. : trades the "1st/3rd/5th"
# jargon for an intuitive skip-a-note recipe.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

TARGET="A chord is a few notes played at the same time; a major chord is the happy-sounding one built from the 1st, 3rd, and 5th notes of a scale."
EXPR=":'a major chord is three notes played together using the first third and fifth notes of a scale'"

echo "TARGET (${#TARGET} chars): $TARGET"
echo "EXPR   (${#EXPR} chars): $EXPR"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
