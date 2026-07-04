#!/usr/bin/env bash
# nlir-golf (aur-2) — "the pizza party": slices per person.
#
#     'three' * 'eight' / 'a dozen'
#      └ 3 ┘    └ 8 ┘    └── 12 ──┘
#      └──── 3 * 8 / 12 = 24 / 12 = 2 ────┘
#
# Three pizzas, eight slices each, split among a dozen people: twenty-four slices
# over twelve is two apiece. Times and divide run left to right, and "a dozen"
# coerces to twelve. Party maths from the words.
#
# Real output (claude-sonnet-5): 2
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR="'three'*'eight'/'a dozen'"

echo "concept:    slices per person -- 3 pizzas * 8 slices / a dozen people = 2"
echo "expression: 'three'*'eight'/'a dozen'"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
