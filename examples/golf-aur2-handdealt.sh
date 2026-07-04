#!/usr/bin/env bash
# nlir-golf (aur-2) — "the hand": a deck dealt among four players.
#
#     'fifty two' / 'four'
#      └── 52 ──┘   └ 4 ┘
#      └──── 52 / 4 = 13 ────┘
#
# A standard deck is fifty-two cards; deal it evenly among four players and each gets
# thirteen -- one full suit's worth. Coercion reads both worded numbers and divides.
# The maths behind a hand of bridge or hearts, from words.
#
# Real output (claude-sonnet-5): 13
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR="'fifty two'/'four'"

echo "concept:    a hand dealt -- 52 cards / 4 players = 13 each"
echo "expression: 'fifty two'/'four'"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
