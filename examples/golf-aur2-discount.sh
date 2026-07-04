#!/usr/bin/env bash
# nlir-golf (aur-2) — "the discount": take a percentage OFF a price, in words.
#
#     'a hundred' - 'a hundred' * 'a fifth'
#      └─ 100 ─┘     └─ 100 ─┘    └─ 0.2 ─┘   ("a fifth" -> the fraction 0.2)
#                     └── 100 * 0.2 = 20 (the 20% off) ──┘
#      └────────── 100 - 20 = 80 (the sale price) ──────────┘
#
# "a fifth" coerces to 0.2, precedence computes the discount before subtracting:
# 20% off a $100 item is $80. The complement of the tip calculator (which adds).
#
# Real output (claude-sonnet-5): 80
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR="'a hundred'-'a hundred'*'a fifth'"

echo "concept:    a price with a 20% discount, written in words"
echo "expression: 'a hundred'-'a hundred'*'a fifth'   (100 - 100*0.2)"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
