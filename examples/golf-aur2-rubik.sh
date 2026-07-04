#!/usr/bin/env bash
# nlir-golf (aur-2) — "the Rubik's cube": three, cubed.
#
#     'three' ** 'three'
#      └ 3 ┘    └ 3 ┘
#      └──── 3 ** 3 = 27 ────┘
#
# A Rubik's cube is three cubies wide, three tall, three deep -- three cubed = 27
# little cubes (26 visible plus one hidden core). Coercion reads the words and the
# power operator does the rest. The puzzle's count, from two number-words.
#
# Real output (claude-sonnet-5): 27
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR="'three'**'three'"

echo "concept:    a Rubik's cube -- 3 x 3 x 3 = 3^3 = 27 cubies"
echo "expression: 'three'**'three'"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
