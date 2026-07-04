#!/usr/bin/env bash
# nlir-golf (aur-2) — "the gigabyte": two, to the thirtieth.
#
#     'two' ** 'thirty'
#      └ 2 ┘    └ 30 ┘
#      └──── 2 ** 30 = 1073741824 ────┘
#
# Memory is counted in powers of two: a byte is 2^8, a kibibyte 2^10, and a GIBIBYTE
# -- one "binary gigabyte" -- is 2^30 = 1,073,741,824 bytes, just over a billion.
# Coercion reads the words, the power operator does the rest. Completes the ladder
# byte (2^8) -> kilobyte (2^10) -> GiB (2^30). Exact (well under 2^53).
#
# Real output (claude-sonnet-5): 1073741824
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR="'two'**'thirty'"

echo "concept:    a gibibyte -- 2^30 = 1,073,741,824 bytes"
echo "expression: 'two'**'thirty'"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
