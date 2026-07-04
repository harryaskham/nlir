#!/usr/bin/env bash
# nlir-golf (aur-2) — "18-karat gold": how pure is it?
#
#     'eighteen' / 'twenty four'
#      └── 18 ──┘   └── 24 ──┘
#      └──── 18 / 24 = 0.75 ────┘
#
# Gold purity is measured in karats out of 24, where 24k is pure. So 18-karat gold
# is 18/24 = 0.75 -- seventy-five percent gold. Coercion reads both spelled-out
# numbers and divides. A jeweller's fraction, from words.
#
# Real output (claude-sonnet-5): 0.75
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR="'eighteen'/'twenty four'"

echo "concept:    18-karat gold purity -- 18 / 24 = 0.75 (75% pure)"
echo "expression: 'eighteen'/'twenty four'"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
