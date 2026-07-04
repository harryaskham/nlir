#!/usr/bin/env bash
# nlir TARGET-GOLF (aur-2 #88) — reverse game via : (simplify): ASTRONOMY jargon
# (a comet) -> plain, 30% shorter; : reaches for the "dirty snowball" picture.
#
# TARGET (~176 chars):
#   "A comet is a chunk of ice and dust that, when it swings near the Sun, heats up and
#    sheds gas and dust -- forming a bright fuzzy head and a long glowing tail streaming
#    behind it."
#
# EXPRESSION (123 chars):
#   :'a comet is an icy body that releases gas and dust forming a glowing coma and a long tail when it passes close to the sun'
#
# Real output (claude-sonnet-5):
#   "A comet is like a big dirty snowball flying through space. When it gets close to the
#    sun, it warms up and starts to melt a little. This makes a bright, glowing cloud
#    around it and a long, sparkly tail behind it!"
# Closeness: same idea (an icy body near the Sun -> releases gas/dust -> a glowing head
# (coma) + tail), plain (high), 30% shorter. : dropped "coma" for "glowing cloud" and
# reached for astronomers' own "dirty snowball" nickname.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

TARGET="A comet is a chunk of ice and dust that, when it swings near the Sun, heats up and sheds gas and dust -- forming a bright fuzzy head and a long glowing tail streaming behind it."
EXPR=":'a comet is an icy body that releases gas and dust forming a glowing coma and a long tail when it passes close to the sun'"

echo "TARGET (${#TARGET} chars): $TARGET"
echo "EXPR   (${#EXPR} chars): $EXPR"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
