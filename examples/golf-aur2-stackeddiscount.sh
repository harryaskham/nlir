#!/usr/bin/env bash
# nlir-golf (aur-2) — "stacked discounts": why 20% then 10% off isn't 30% off.
#
#     'a hundred' * ('1' - '20%') * ('1' - '10%')
#      └── 100 ──┘   └ 1  ┘└ .2 ┘   └ 1  ┘└ .1 ┘
#      └──── 100 * 0.8 * 0.9 = 72 ────┘
#
# Two discounts don't add -- they multiply. A hundred-dollar item at "20% off then
# 10% off" is 100 * 0.8 * 0.9 = 72, NOT 70. Coercion reads the percent-literals as
# fractions and the nesting applies each cut to what's left. The classic sale-sign trap.
#
# Real output (claude-sonnet-5): 72
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR="'a hundred'*('1'-'20%')*('1'-'10%')"

echo "concept:    stacked discounts -- 100 * (1-20%) * (1-10%) = 72 (not 70)"
echo "expression: 'a hundred'*('1'-'20%')*('1'-'10%')"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
