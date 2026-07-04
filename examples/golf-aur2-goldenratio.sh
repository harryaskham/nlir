#!/usr/bin/env bash
# nlir-golf (aur-2) — "the golden ratio": (1 + root five) over two.
#
#     ('1' + 'five' ** '0.5') / 'two'
#      └ 1 ┘  └ 5 ┘   └.5┘      └ 2 ┘
#      └──── (1 + sqrt(5)) / 2 = (1 + 2.2360679...) / 2 = 1.6180339... ────┘
#
# The golden ratio phi = (1 + sqrt 5) / 2. Raising five to the power one-half IS its
# square root (as in golf-aur2-hypotenuse), the parentheses add one, then divide by
# two. nlir lands 1.618033988749895 -- phi to f64 precision (it's irrational, so this
# is the closest a double can hold).
#
# Real output (claude-sonnet-5): 1.618033988749895
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR="('1'+'five'**'0.5')/'two'"

echo "concept:    the golden ratio phi = (1 + sqrt 5) / 2 = 1.618..."
echo "expression: ('1'+'five'**'0.5')/'two'"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
