#!/usr/bin/env bash
# nlir TARGET-GOLF (aur-2 #77) — reverse game via ~> (summary of expand): a dense
# TECHNICAL one-liner defining an engineering concept from a 26-char seed.
#
# TARGET (~209 chars):
#   "Technical debt is the future cost you take on when you choose a quick or easy
#    solution now instead of a better one -- like a shortcut that saves time today but
#    slows you down later until you go back and fix it."
#
# EXPRESSION (26 chars):
#   ~>'what is technical debt'
#
# Real output (claude-sonnet-5):
#   "Technical debt is the metaphorical cost of future rework incurred when developers
#    choose quick, expedient solutions over better, slower ones, and unmanaged debt
#    gradually hurts development speed, quality, and maintainability."
# Closeness: same core (future-rework cost of choosing quick over better), and ~> adds
# the consequence (hurts speed/quality/maintainability) in a technical register (high).
# 88% shorter -- 26 characters into a full definition.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

TARGET="Technical debt is the future cost you take on when you choose a quick or easy solution now instead of a better one -- like a shortcut that saves time today but slows you down later until you go back and fix it."
EXPR="~>'what is technical debt'"

echo "TARGET (${#TARGET} chars): $TARGET"
echo "EXPR   (${#EXPR} chars): $EXPR"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
