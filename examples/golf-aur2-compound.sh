#!/usr/bin/env bash
# nlir-golf (aur-2) — "compound growth" (and an honest f64 lesson): $1000 at 10% for
# two years.
#
#     'a thousand' * ('1' + '10%') ** 'two'
#      └── 1000 ──┘   └ 1 ┘ └ .1 ┘   └ 2 ┘
#      └──── 1000 * (1.1 ** 2) = 1000 * 1.21 = 1210 (in exact math) ────┘
#
# Compound interest: principal * (1 + rate)^years. Precedence squares the growth
# factor first (1.1^2), then multiplies. The exact answer is 1210 -- but nlir's values
# are f64, and 1.1 (like 0.1) has no exact binary representation, so 1.1^2 lands on
# 1.2100000000000002 and the result PRINTS as 1210.0000000000002. A real, honest
# demonstration of the floating-point limit (cf. golf-aur2-ceiling, bd-50f84a):
# the arithmetic is right, the last bit is the price of binary fractions.
#
# Real output (claude-sonnet-5): 1210.0000000000002
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR="'a thousand'*('1'+'10%')**'two'"

echo "concept:    compound growth -- 1000 * (1+10%)^2 (exact 1210; f64 prints ...0002)"
echo "expression: 'a thousand'*('1'+'10%')**'two'"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
