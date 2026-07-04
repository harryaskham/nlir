#!/usr/bin/env bash
# nlir-golf (aur-2) — "the salary": an hourly wage, annualised.
#
#     'twenty' * 'forty' * 'fifty'
#      └─ 20 ─┘   └ 40 ┘   └ 50 ┘
#      └──── 20 * 40 * 50 = 40000 ────┘
#
# Twenty dollars an hour, forty hours a week, fifty working weeks a year: multiply
# them and you get a forty-thousand-dollar annual salary. Coercion reads all three
# worded numbers and the multiplies chain left to right. A year's pay, from three words.
#
# Real output (claude-sonnet-5): 40000
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR="'twenty'*'forty'*'fifty'"

echo "concept:    annual salary -- \$20/hr * 40 hr/wk * 50 wk = \$40,000"
echo "expression: 'twenty'*'forty'*'fifty'"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
