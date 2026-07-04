#!/usr/bin/env bash
# nlir-golf (aur-2) — "a byte": two, to the eighth.
#
#     'two' ** 'eight'
#      └ 2 ┘    └ 8 ┘
#      └── 2 ** 8 = 256 ──┘
#
# A byte is eight bits, and each bit is a 0 or a 1 -- so a byte holds 2^8 = 256
# distinct values (0 to 255). Coercion reads the words, the power operator counts
# the combinations. The atom of computing, from two number-words.
#
# Real output (claude-sonnet-5): 256
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR="'two'**'eight'"

echo "concept:    a byte -- 8 bits, 2^8 = 256 values (0..255)"
echo "expression: 'two'**'eight'"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
