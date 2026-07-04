#!/usr/bin/env bash
# nlir-golf (aur-2) — "the deck": four suits times thirteen ranks makes a 52-card deck.
#
#     'four' * 'thirteen'
#      └ 4 ┘    └ 13 ┘
#      └── 4 * 13 = 52 ──┘
#
# Coercion reads both worded numbers and multiplies: a standard deck has four
# suits of thirteen cards each -- 52 in all. Trivia straight from the words.
#
# Real output (claude-sonnet-5): 52
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR="'four'*'thirteen'"

echo "concept:    cards in a deck -- four suits * thirteen ranks"
echo "expression: 'four'*'thirteen'   (4 * 13)"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
