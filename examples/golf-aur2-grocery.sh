#!/usr/bin/env bash
# nlir-golf (aur-2) — "the grocery tally": coercion pulls the COUNT out of each
# noun phrase, then sums the list.
#
#     + [ 'a dozen eggs' , 'half a dozen apples' , 'a couple oranges' ]
#          └──── 12 ────┘   └──────── 6 ────────┘   └───── 2 ──────┘
#          └──────────────── 12 + 6 + 2 = 20 ─────────────────┘
#
# Each item is a whole noun phrase, but coercion reads past the noun to the
# quantity (a dozen EGGS -> 12), and the list SPREADS into + -> a running total.
# A shopping list totted up in plain English.
#
# Real output (claude-sonnet-5): 20
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR="+['a dozen eggs','half a dozen apples','a couple oranges']"

echo "concept:    sum the quantities pulled from a list of noun phrases"
echo "expression: +['a dozen eggs','half a dozen apples','a couple oranges']"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
