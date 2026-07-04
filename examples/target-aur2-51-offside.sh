#!/usr/bin/env bash
# nlir TARGET-GOLF (aur-2 #51) — reverse game via : (simplify): SOCCER's most
# notorious rule (offside) -> plain English.
#
# TARGET (~147 chars):
#   "In soccer you are offside if, the moment a teammate passes you the ball, you are
#    closer to the goal than the ball and all but one of the defenders."
#
# EXPRESSION (156 chars):
#   :'in soccer a player is offside if they are nearer to the opponents goal than both the ball and the second-to-last defender when the ball is played to them'
#
# Real output (claude-sonnet-5):
#   "In soccer, you're offside if you stand too close to the other team's goal --
#    closer than the ball, and closer than almost all the other team's players --
#    right when your teammate kicks the ball to you."
# Closeness: same rule (closer to goal than the ball AND all-but-one defenders at
# the moment of the pass), plain (high), ~even length. : turns "second-to-last
# defender" into "almost all the other team's players".
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

TARGET="In soccer you are offside if, the moment a teammate passes you the ball, you are closer to the goal than the ball and all but one of the defenders."
EXPR=":'in soccer a player is offside if they are nearer to the opponents goal than both the ball and the second-to-last defender when the ball is played to them'"

echo "TARGET (${#TARGET} chars): $TARGET"
echo "EXPR   (${#EXPR} chars): $EXPR"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
