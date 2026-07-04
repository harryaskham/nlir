#!/usr/bin/env bash
# nlir-golf (aur-2) — "the leap year": three hundred sixty five, plus one.
#
#     'three hundred sixty five' + 'one'
#      └──────── 365 ────────┘     └ 1 ┘
#      └──────── 365 + 1 = 366 ────────┘
#
# Coercion reads the fully-spelled-out compound number (three hundred sixty five
# -> 365) and adds one: 366, the number of days in a leap year. Even long, written-
# out numbers become values.
#
# Real output (claude-sonnet-5): 366
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR="'three hundred sixty five'+'one'"

echo "concept:    a leap year -- 365 (spelled out) + 1 = 366"
echo "expression: 'three hundred sixty five'+'one'"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
