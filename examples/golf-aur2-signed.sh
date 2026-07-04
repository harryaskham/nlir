#!/usr/bin/env bash
# nlir-golf (aur-2) — "the signed-word calculator": coercion reads NEGATIVE number
# words, not just positive ones.
#
#     'negative three' + 'a dozen'
#      └──── -3 ────┘   └── 12 ──┘   (a signed word coerced to a negative number)
#      └────────── -3 + 12 = 9 ──────────┘
#
# "negative three" -> -3: the coercion layer carries the SIGN, so worded arithmetic
# crosses zero correctly. A calculator that reads minus signs spelled out in words.
#
# Real output (claude-sonnet-5): 9
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR="'negative three'+'a dozen'"

echo "concept:    arithmetic over SIGNED number words (negative three -> -3)"
echo "expression: 'negative three'+'a dozen'   (-3 + 12)"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
