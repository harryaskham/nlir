#!/usr/bin/env bash
# nlir-golf (aur-2) — "the great gross": a dozen, cubed.
#
#     'a dozen' ** 'three'
#      └── 12 ──┘   └ 3 ┘
#      └──── 12 ** 3 = 1728 ────┘
#
# A gross is a dozen dozen (144); a GREAT gross is a dozen dozen dozen -- 12 cubed
# = 1728. Coercion reads the quantity-word and the exponent, the power operator
# does the rest. An old unit of counting, computed from words.
#
# Real output (claude-sonnet-5): 1728
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR="'a dozen'**'three'"

echo "concept:    a great gross -- a dozen cubed (12^3 = 1728)"
echo "expression: 'a dozen'**'three'"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
