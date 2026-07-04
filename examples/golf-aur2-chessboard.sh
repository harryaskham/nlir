#!/usr/bin/env bash
# nlir-golf (aur-2) — "the chessboard": eight, squared.
#
#     'eight' ** 'two'
#      └ 8 ┘    └ 2 ┘
#      └── 8 ** 2 = 64 ──┘
#
# A chessboard is eight squares by eight -- 8 squared = 64 squares. Coercion reads
# the words and the power operator squares them. The board of kings and queens,
# counted from two number-words.
#
# Real output (claude-sonnet-5): 64
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR="'eight'**'two'"

echo "concept:    a chessboard -- 8 by 8 (8^2 = 64 squares)"
echo "expression: 'eight'**'two'"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
