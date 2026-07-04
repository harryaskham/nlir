#!/usr/bin/env bash
# nlir-golf (aur-2) — "base36": twenty-six letters plus ten digits makes 36 --
# why base36 encodes with exactly 36 characters.
#
#     'twenty six' + 'ten'
#      └── 26 ──┘    └ 10 ┘
#      └──── 26 + 10 = 36 ────┘
#
# Coercion reads both worded numbers and adds: the 26 letters of the alphabet plus
# the 10 digits give the 36 symbols of base36. A slice of encoding trivia from words.
#
# Real output (claude-sonnet-5): 36
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR="'twenty six'+'ten'"

echo "concept:    base36 -- 26 letters + 10 digits = 36 symbols"
echo "expression: 'twenty six'+'ten'   (26 + 10)"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
