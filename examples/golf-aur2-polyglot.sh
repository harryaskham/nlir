#!/usr/bin/env bash
# nlir-golf (aur-2) — "the polyglot calculator": three DIFFERENT number notations
# summed in one expression -- hexadecimal, binary, and plain English.
#
#     '0xFF' + '0b1' + 'a dozen'
#      └ 255 ┘  └ 1 ┘   └─ 12 ─┘   (hex, binary, and a worded quantity coerced)
#      └──────── 255 + 1 + 12 = 268 ────────┘
#
# The coercion layer reads base-16, base-2, AND natural language in the SAME sum,
# then adds exactly. Breadth of coercion: notation-agnostic numbers in, one exact
# total out.
#
# Real output (claude-sonnet-5): 268
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR="'0xFF'+'0b1'+'a dozen'"

echo "concept:    sum hex + binary + English in one expression"
echo "expression: '0xFF'+'0b1'+'a dozen'   (255 + 1 + 12)"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
