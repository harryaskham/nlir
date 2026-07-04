#!/usr/bin/env bash
# nlir TARGET-GOLF (aur-2 #33) — reverse game via : (simplify): a notoriously
# confusing SPORTS RULE (cricket's LBW) -> plain English.
#
# TARGET (~169 chars):
#   "In cricket, if the ball hits the batsman's leg and the umpire thinks it would
#    otherwise have hit the stumps, the batsman is out even though the ball never
#    touched the bat."
#
# EXPRESSION (111 chars):
#   :'in cricket a batsman is out leg before wicket if the ball would have hit the stumps but struck the pad first'
#
# Real output (claude-sonnet-5):
#   "In cricket, a player is out if the ball hits their leg first, but the ball
#    would have hit the wickets if the leg wasn't in the way."
# Closeness: same rule (leg blocks a ball that would have hit the stumps -> out),
# plain (high), and 34% shorter than the target. : drops the jargon "LBW".
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

TARGET="In cricket, if the ball hits the batsman's leg and the umpire thinks it would otherwise have hit the stumps, the batsman is out even though the ball never touched the bat."
EXPR=":'in cricket a batsman is out leg before wicket if the ball would have hit the stumps but struck the pad first'"

echo "TARGET (${#TARGET} chars): $TARGET"
echo "EXPR   (${#EXPR} chars): $EXPR"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
