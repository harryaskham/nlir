#!/usr/bin/env bash
# nlir-golf (aur-2) — "the mortgage": a thirty-year loan, in monthly payments.
#
#     'thirty' * 'twelve'
#      └─ 30 ─┘   └ 12 ┘
#      └──── 30 * 12 = 360 ────┘
#
# A thirty-year mortgage is paid monthly, and there are twelve months a year -- so it
# runs 30 * 12 = 360 payments. Coercion reads both worded numbers and multiplies.
# The long arc of a home loan, counted in cheques.
#
# Real output (claude-sonnet-5): 360
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR="'thirty'*'twelve'"

echo "concept:    a 30-year mortgage in monthly payments -- 30 * 12 = 360"
echo "expression: 'thirty'*'twelve'"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
