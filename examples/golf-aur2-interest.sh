#!/usr/bin/env bash
# nlir-golf (aur-2) — "the interest": a thousand, times five percent.
#
#     'a thousand' * '5%'
#      └── 1000 ──┘  └ 0.05 ┘
#      └──── 1000 * 0.05 = 50 ────┘
#
# Simple interest: principal times rate. Coercion reads "a thousand" as 1000 and the
# percent-literal "5%" as 0.05, so a thousand at five percent earns fifty. Money math
# where the rate is written the way a human writes it.
#
# Real output (claude-sonnet-5): 50
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR="'a thousand'*'5%'"

echo "concept:    simple interest -- principal * rate (1000 * 5% = 50)"
echo "expression: 'a thousand'*'5%'"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
