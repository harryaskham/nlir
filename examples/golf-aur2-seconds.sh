#!/usr/bin/env bash
# nlir-golf (aur-2) — "the day in seconds": how many seconds in a day, computed
# from worded numbers.
#
#     'sixty' * 'sixty' * 'twenty four'
#      └ 60 ┘    └ 60 ┘    └── 24 ──┘
#      └──── 60 * 60 * 24 = 86400 ────┘
#
# sixty seconds a minute, sixty minutes an hour, twenty-four hours a day: the
# coercion layer reads the words and multiplies out to 86,400 seconds in a day.
#
# Real output (claude-sonnet-5): 86400
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR="'sixty'*'sixty'*'twenty four'"

echo "concept:    seconds in a day, from worded numbers (60 * 60 * 24)"
echo "expression: 'sixty'*'sixty'*'twenty four'"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
