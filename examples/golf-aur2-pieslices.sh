#!/usr/bin/env bash
# nlir-golf (aur-2) — "the pie": a whole, divided by an eighth.
#
#     'a whole' / 'an eighth'
#      └── 1 ──┘   └ 0.125 ┘
#      └──── 1 / 0.125 = 8 ────┘
#
# Cut a whole pie into eighths and you get eight slices. Coercion reads the FRACTION-
# words -- "a whole" is 1, "an eighth" is 0.125 -- and dividing one by an eighth is
# eight. How many pieces fit, computed from the words for the pieces.
#
# Real output (claude-sonnet-5): 8
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR="'a whole'/'an eighth'"

echo "concept:    slices in a pie -- a whole / an eighth = 1 / 0.125 = 8"
echo "expression: 'a whole'/'an eighth'"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
