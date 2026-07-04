#!/usr/bin/env bash
# nlir-golf (aur-2) — "the restaurant bill": a COMBO calc — add a tip, then split
# the total — in one coerced expression.
#
#     ( 'sixty' + 'sixty' * 'a fifth' ) / 'four'
#       └─ 60 ─┘  └─ 60 ─┘  └─ 0.2 ─┘     └ 4 ┘
#       └──── 60 + (60 * 0.2) = 72 ────┘  / 4  =  18
#
# Precedence does the 20% tip first (60*0.2=12 -> 72), the grouping splits the
# total four ways: a $60 dinner, tipped 20%, split between four = $18 each.
# The tip calculator and the bill-splitter, composed.
#
# Real output (claude-sonnet-5): 18
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR="('sixty'+'sixty'*'a fifth')/'four'"

echo "concept:    a restaurant bill -- add 20% tip, then split 4 ways"
echo "expression: ('sixty'+'sixty'*'a fifth')/'four'   ((60 + 60*0.2) / 4)"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
