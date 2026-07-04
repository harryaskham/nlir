#!/usr/bin/env bash
# nlir-golf (aur-2) — "the three bases": octal, hex, and binary literals, summed.
#
#     '0o17'  +  '0xF'  +  '0b1'
#      └ 15 ┘     └ 15 ┘    └ 1 ┘   (octal / hexadecimal / binary)
#      └──── 15 + 15 + 1 = 31 ────┘
#
# 0o17 is octal (fifteen), 0xF is hex (fifteen), 0b1 is binary (one): the three
# base-prefix notations a programmer uses, coerced side by side and added to 31.
# nlir reads every base a source file might.
#
# Real output (claude-sonnet-5): 31
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR="'0o17'+'0xF'+'0b1'"

echo "concept:    octal + hex + binary literals coerced and summed (15+15+1)"
echo "expression: '0o17'+'0xF'+'0b1'"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
