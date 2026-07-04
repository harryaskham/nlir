#!/usr/bin/env bash
# nlir-golf (aur-2) — "the seconds in a year": sixty, sixty, twenty-four, three-sixty-five.
#
#     'sixty' * 'sixty' * 'twenty four' * 'three hundred sixty five'
#      └60┘     └60┘      └24┘             └365┘
#      └──── 60 * 60 * 24 * 365 = 31,536,000 ────┘
#
# Seconds in a minute times minutes in an hour times hours in a day times days in a year:
# 31,536,000 seconds. The famous back-of-envelope coincidence -- that's almost exactly
# pi times ten-to-the-seventh (31,415,927), within half a percent. Coercion reads all
# four number-words, including the long-spelled "three hundred sixty five".
#
# Real output (claude-sonnet-5): 31536000
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR="'sixty'*'sixty'*'twenty four'*'three hundred sixty five'"

echo "concept:    seconds in a year -- 60*60*24*365 = 31,536,000 (~ pi x 10^7)"
echo "expression: 'sixty'*'sixty'*'twenty four'*'three hundred sixty five'"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
