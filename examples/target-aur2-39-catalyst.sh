#!/usr/bin/env bash
# nlir TARGET-GOLF (aur-2 #39) — reverse game via : (simplify): CHEMISTRY jargon
# -> plain, and a genuine COMPRESSION win (32% shorter than the target).
#
# TARGET (~135 chars):
#   "A catalyst is something that makes a chemical reaction go faster but comes out
#    unchanged at the end, so it can be used again and again."
#
# EXPRESSION (92 chars):
#   :'a catalyst is a substance that speeds up a chemical reaction without being consumed by it'
#
# Real output (claude-sonnet-5):
#   "A catalyst is something that helps a chemical reaction happen faster, but it
#    doesn't get used up while it does this."
# Closeness: same concept (speeds a reaction up, not consumed), plain (high), and
# 32% shorter than the target -- : here compresses AND clarifies.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

TARGET="A catalyst is something that makes a chemical reaction go faster but comes out unchanged at the end, so it can be used again and again."
EXPR=":'a catalyst is a substance that speeds up a chemical reaction without being consumed by it'"

echo "TARGET (${#TARGET} chars): $TARGET"
echo "EXPR   (${#EXPR} chars): $EXPR"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
