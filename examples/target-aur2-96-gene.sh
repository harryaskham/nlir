#!/usr/bin/env bash
# nlir TARGET-GOLF (aur-2 #96) — reverse game via : (simplify): GENETICS jargon
# (a gene) -> plain; : reaches for an "instruction card" analogy + concrete traits.
#
# TARGET (~195 chars):
#   "A gene is a small stretch of DNA that acts like a recipe for building one specific
#    protein -- and it's the basic unit of heredity, the thing parents pass to their
#    children that shapes their traits."
#
# EXPRESSION (157 chars):
#   :'a gene is a segment of DNA that contains the instructions for making a specific protein and is the basic unit of heredity passed from parents to offspring'
#
# Real output (claude-sonnet-5):
#   "A gene is like a tiny instruction card inside your body. It tells your body how to
#    make one special piece it needs to grow and work. You get these instruction cards
#    from your mom and dad, and they help decide things about you, like your eye color
#    or how tall you might be."
# Closeness: same idea (a stretch of DNA = instructions for one protein; the unit of
# heredity passed parent->child, shaping traits), plain (high). : added concrete traits
# (eye colour, height) and runs a bit longer (ELI5 on an approachable topic).
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

TARGET="A gene is a small stretch of DNA that acts like a recipe for building one specific protein -- and it's the basic unit of heredity, the thing parents pass to their children that shapes their traits."
EXPR=":'a gene is a segment of DNA that contains the instructions for making a specific protein and is the basic unit of heredity passed from parents to offspring'"

echo "TARGET (${#TARGET} chars): $TARGET"
echo "EXPR   (${#EXPR} chars): $EXPR"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
