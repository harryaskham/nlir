#!/usr/bin/env bash
# nlir-golf (aur-2) — "a life in days": thirty years, in days.
#
#     'thirty' * 'three hundred sixty five'
#      └─ 30 ─┘   └──────── 365 ────────┘
#      └──── 30 * 365 = 10950 ────┘
#
# A thirty-year-old has lived about thirty times three hundred sixty five days --
# 10,950 of them (ignoring leap days). Coercion reads a short number and a long
# spelled-out one and multiplies. A lifetime, counted in sunrises.
#
# Real output (claude-sonnet-5): 10950
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR="'thirty'*'three hundred sixty five'"

echo "concept:    a life in days -- 30 years * 365 = 10,950 days"
echo "expression: 'thirty'*'three hundred sixty five'"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
