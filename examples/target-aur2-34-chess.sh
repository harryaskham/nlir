#!/usr/bin/env bash
# nlir TARGET-GOLF (aur-2 #34) — reverse game via : (simplify): another notoriously
# fiddly RULE (chess castling, with all its conditions) -> plain English.
#
# TARGET (~186 chars):
#   "Castling is a special chess move where the king slides two squares toward a
#    rook and that rook hops to the king's other side, allowed only if neither
#    piece has moved and the king is safe."
#
# EXPRESSION (161 chars):
#   :'in chess castling lets the king move two squares toward a rook and the rook jumps to the other side but only if neither has moved and the king is not in check'
#
# Real output (claude-sonnet-5):
#   "In chess, there's a special move called castling. The king takes two steps
#    toward one of his rooks, and then that rook hops over to stand next to him on
#    the other side. You can only do this if the king and that rook haven't moved
#    yet, and if the king isn't in check."
# Closeness: same rule with ALL conditions preserved (two-square king move, rook
# jump, both-unmoved, not-in-check), plain + friendly register (high). 13% shorter.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

TARGET="Castling is a special chess move where the king slides two squares toward a rook and that rook hops to the king's other side, allowed only if neither piece has moved and the king is safe."
EXPR=":'in chess castling lets the king move two squares toward a rook and the rook jumps to the other side but only if neither has moved and the king is not in check'"

echo "TARGET (${#TARGET} chars): $TARGET"
echo "EXPR   (${#EXPR} chars): $EXPR"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
