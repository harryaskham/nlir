#!/usr/bin/env bash
# nlir-golf (aur-2) — "the average rating": aggregate worded review scores into a
# number, via coercion + arithmetic.
#
#     ( + [ 'four stars' , 'five stars' , 'three stars' ] ) / 'three'
#         └──── 4 ────┘   └──── 5 ────┘   └──── 3 ────┘        └─ 3 ─┘
#         each rating phrase LLM-coerced to its number; spread into +
#         └────────────── 12 ──────────────┘  ÷  3  =  4
#
# Words like "four stars" become 4, sum to 12, divided by three reviews = a mean
# score of 4. Turn a pile of natural-language ratings into one average.
#
# Real output (claude-sonnet-5): 4
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR="(+['four stars','five stars','three stars'])/'three'"

echo "concept:    average worded review scores (four stars -> 4)"
echo "expression: (+['four stars','five stars','three stars'])/'three'"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
