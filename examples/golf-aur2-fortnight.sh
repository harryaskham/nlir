#!/usr/bin/env bash
# nlir-golf (aur-2) — "a fortnight in hours": a fortnight, times twenty-four.
#
#     'a fortnight' * 'twenty four'
#      └─── 14 ────┘   └── 24 ──┘
#      └──── 14 * 24 = 336 ────┘
#
# Coercion reads a DURATION-word: "a fortnight" is fourteen days, and times twenty-
# four hours a day gives 336 hours. Not just number-words -- units of time coerce to
# their count too, then the arithmetic runs.
#
# Real output (claude-sonnet-5): 336
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR="'a fortnight'*'twenty four'"

echo "concept:    a fortnight in hours -- 14 days * 24 h/day = 336"
echo "expression: 'a fortnight'*'twenty four'"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
