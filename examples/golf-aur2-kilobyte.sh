#!/usr/bin/env bash
# nlir-golf (aur-2) — "the kilobyte": two to the tenth is 1024 -- why a kilobyte
# isn't quite a thousand bytes.
#
#     'two' ** 'ten'
#      └ 2 ┘    └ 10 ┘
#      └── 2 ** 10 = 1024 ──┘
#
# Coercion reads both worded numbers and the (right-associative) power operator
# raises: 2^10 = 1024, the number of bytes in a kilobyte. CS trivia from two words.
#
# Real output (claude-sonnet-5): 1024
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR="'two'**'ten'"

echo "concept:    a kilobyte -- two to the tenth power (2^10)"
echo "expression: 'two'**'ten'"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
