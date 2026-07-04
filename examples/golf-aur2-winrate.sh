#!/usr/bin/env bash
# nlir-golf (aur-2) — "the win-rate": turn a worded record into a percentage.
#
#     ( 'seven' / 'ten' ) * 'a hundred'
#       └─ 7 ─┘  └ 10 ┘     └── 100 ──┘   (each worded number coerced)
#       └──── 7/10 = 0.7 ────┘  * 100  =  70
#
# Coercion reads the words, the grouping does the ratio first, then scales to a
# percentage: a 7-out-of-10 record is 70%. A stats calculator in plain English.
#
# Real output (claude-sonnet-5): 70
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR="('seven'/'ten')*'a hundred'"

echo "concept:    a worded win/loss record -> a percentage"
echo "expression: ('seven'/'ten')*'a hundred'   ((7/10)*100)"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
