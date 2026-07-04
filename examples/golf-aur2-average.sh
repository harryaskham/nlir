#!/usr/bin/env bash
# nlir-golf (aur-2) — "the average": three scores, summed and divided.
#
#     ('eighty' + 'ninety' + 'a hundred') / 'three'
#      └─ 80 ─┘   └─ 90 ─┘    └── 100 ──┘    └ 3 ┘
#      └──────── (80 + 90 + 100) / 3 = 270 / 3 = 90 ────────┘
#
# The mean of three test scores. The parentheses sum first (270), then the divide by
# three gives the average, 90. Coercion reads every worded number, and the grouping
# makes the arithmetic happen in the right order.
#
# Real output (claude-sonnet-5): 90
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR="('eighty'+'ninety'+'a hundred')/'three'"

echo "concept:    the average -- (80 + 90 + 100) / 3 = 90"
echo "expression: ('eighty'+'ninety'+'a hundred')/'three'"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
