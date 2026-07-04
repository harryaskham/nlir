#!/usr/bin/env bash
# nlir-golf (aur-2) — "the mixed number": coercion reads a whole-plus-fraction
# phrase as one value.
#
#     'two and a half' + 'one and a half'
#      └──── 2.5 ────┘    └──── 1.5 ────┘
#      └──── 2.5 + 1.5 = 4 ────┘
#
# "two and a half" -> 2.5, "one and a half" -> 1.5: the coercion layer folds the
# whole number and its fraction into a single value, then adds -- 4. Mixed numbers,
# spelled the way you'd say them.
#
# Real output (claude-sonnet-5): 4
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR="'two and a half'+'one and a half'"

echo "concept:    coerce mixed numbers (two and a half -> 2.5), then add"
echo "expression: 'two and a half'+'one and a half'   (2.5 + 1.5)"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
