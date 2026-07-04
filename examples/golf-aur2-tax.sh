#!/usr/bin/env bash
# nlir-golf (aur-2) — "the receipt with tax": a COMBO calc gluing two coercion
# notations -- currency and a percent -- into a real checkout total.
#
#     ( '$19.99' + '$5.01' ) * ( 1 + '8%' )
#       └ 19.99 ┘  └ 5.01 ┘        └ 0.08 ┘
#       └─── $25.00 subtotal ───┘ * └ 1.08 ┘  =  27
#
# The prices add to a $25 subtotal; "8%" coerces to 0.08, so (1 + 8%) = 1.08 is
# the tax multiplier. $25 plus 8% sales tax = $27. Currency and percent, composed.
#
# Real output (claude-sonnet-5): 27
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

echo "concept:    a checkout total -- add two prices, then add 8% sales tax"
echo "expression: ('\$19.99'+'\$5.01')*(1+'8%')   (\$25 * 1.08)"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "('\$19.99'+'\$5.01')*(1+'8%')"
