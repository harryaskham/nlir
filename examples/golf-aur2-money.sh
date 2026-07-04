#!/usr/bin/env bash
# nlir-golf (aur-2) — "the money reader": coercion reads numbers written the human
# way -- dollar signs, decimals, and comma-grouped thousands.
#
#     '$19.99' + '$5.01'            '1,000,000' - '999,999'
#      └ 19.99 ┘  └ 5.01 ┘           └ 1000000 ┘  └ 999999 ┘
#      └── 19.99 + 5.01 = 25 ──┘     └── 1000000 - 999999 = 1 ──┘
#
# The $ and the decimals read as a price; the thousands-commas are stripped to a
# plain integer. So two prices add to exactly $25, and a million minus 999,999 is
# 1 -- money and big numbers written the everyday way, computed exactly.
#
# Real output (claude-sonnet-5):  '$19.99'+'$5.01' -> 25   ;   '1,000,000'-'999,999' -> 1
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

echo "concept:    coerce currency (\$19.99) and comma-grouped thousands (1,000,000)"
echo "--- '\$19.99'+'\$5.01'  (a price sum) ---"
"$NLIR" --context-file "$CTX" --mode llm -e "'\$19.99'+'\$5.01'"; rm -f "$CTX"
echo "--- '1,000,000'-'999,999'  (comma thousands) ---"
"$NLIR" --context-file "$CTX" --mode llm -e "'1,000,000'-'999,999'"
