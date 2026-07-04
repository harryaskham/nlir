#!/usr/bin/env bash
# nlir-golf (aur-2) — "dog years": a dozen, times seven.
#
#     'a dozen' * 'seven'
#      └── 12 ──┘  └ 7 ┘
#      └──── 12 * 7 = 84 ────┘
#
# The folk rule that one human year is seven dog years: a dozen-year-old dog is
# "84" in dog years. Coercion reads the quantity-word (a dozen -> 12) and the
# multiplier, and out comes the number behind an old bit of pet-owner lore.
#
# Real output (claude-sonnet-5): 84
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR="'a dozen'*'seven'"

echo "concept:    dog years -- a dozen dog-years-per-human-year (12 * 7 = 84)"
echo "expression: 'a dozen'*'seven'"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
