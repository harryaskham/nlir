#!/usr/bin/env bash
# nlir-golf (aur-2) — "the chromosomes": twenty-three pairs.
#
#     'twenty three' * 'two'
#      └──── 23 ────┘   └ 2 ┘
#      └──── 23 * 2 = 46 ────┘
#
# Humans carry twenty-three PAIRS of chromosomes -- one of each pair from each
# parent -- so twenty-three times two is forty-six, the full complement. Coercion
# reads both worded numbers and multiplies. The count that makes a human, from words.
#
# Real output (claude-sonnet-5): 46
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR="'twenty three'*'two'"

echo "concept:    human chromosomes -- 23 pairs * 2 = 46"
echo "expression: 'twenty three'*'two'"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
