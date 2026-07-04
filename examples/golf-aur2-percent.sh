#!/usr/bin/env bash
# nlir-golf (aur-2) — "the fuzzy percentage": coercion reads FRACTIONS, not just
# whole quantities, then does the maths.
#
#     'two hundred' * 'a tenth'
#      └── 200 ──┘     └─ 0.1 ─┘    (each LLM-coerced -- note the FRACTION)
#      └──────── 200 * 0.1 = 20 ────┘
#
# The coercion layer reads "a tenth" as 0.1 (not 10), so multiplying gives
# "10% of 200 = 20". Fuzzy fractions in, exact percentage out.
#
# Real output (claude-sonnet-5): 20
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR="'two hundred'*'a tenth'"

echo "concept:    percentage-of via fuzzy fractional coercion (a tenth -> 0.1)"
echo "expression: 'two hundred'*'a tenth'   (200 * 0.1)"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
