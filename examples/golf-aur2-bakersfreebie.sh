#!/usr/bin/env bash
# nlir-golf (aur-2) — "the baker's freebie": a baker's dozen minus a dozen = 1.
#
#     'a bakers dozen' - 'a dozen'
#      └──── 13 ────┘    └── 12 ──┘
#      └──── 13 - 12 = 1 ────┘
#
# a baker's dozen coerces to 13, a dozen to 12: the difference is 1 -- the single
# extra loaf a baker throws in for luck. Two folklore quantities, one exact answer.
#
# Real output (claude-sonnet-5): 1
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR="'a bakers dozen'-'a dozen'"

echo "concept:    a baker's dozen (13) minus a dozen (12) = 1 (the free extra)"
echo "expression: 'a bakers dozen'-'a dozen'"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
