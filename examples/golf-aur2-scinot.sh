#!/usr/bin/env bash
# nlir-golf (aur-2) — "the scientific-notation calculator": coercion reads
# exponent notation, then does the maths.
#
#     '1e3' + '5e2'
#      └ 1000 ┘ └ 500 ┘    (each scientific-notation literal coerced)
#      └──── 1000 + 500 = 1500 ────┘
#
# 1e3 -> 1000, 5e2 -> 500: exponent-notation numbers a text box rarely accepts,
# summed exactly. Another notation the coercion layer just reads (cf. hex/roman).
#
# Real output (claude-sonnet-5): 1500
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR="'1e3'+'5e2'"

echo "concept:    arithmetic over scientific notation (1e3 -> 1000)"
echo "expression: '1e3'+'5e2'   (1000 + 500)"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
