#!/usr/bin/env bash
# nlir-golf (aur-2) — "boiling in Kelvin": Celsius plus the offset.
#
#     'a hundred' + 'two hundred seventy three'
#      └── 100 ──┘   └──────── 273 ────────┘
#      └──── 100 + 273 = 373 ────┘
#
# The Kelvin scale is Celsius shifted by 273 (absolute zero is -273 C), so water's
# boiling point, 100 C, is 373 K. Coercion reads both the short and the long spelled-
# out number and adds them. A change of temperature scale, in words.
# (273.15 to be exact; 273 is the schoolroom constant.)
#
# Real output (claude-sonnet-5): 373
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR="'a hundred'+'two hundred seventy three'"

echo "concept:    Celsius -> Kelvin -- 100 C + 273 = 373 K (water boils)"
echo "expression: 'a hundred'+'two hundred seventy three'"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
