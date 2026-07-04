#!/usr/bin/env bash
# nlir-golf (aur-2) — "true color": two, to the twenty-fourth.
#
#     'two' ** 'twenty four'
#      └ 2 ┘    └── 24 ──┘
#      └──── 2 ** 24 = 16777216 ────┘
#
# 24-bit "true color" packs eight bits each for red, green, and blue -- 2^24 distinct
# colors, about 16.7 million. Coercion reads the words, the power operator does the
# rest. Every shade your screen can show, from two number-words.
#
# Real output (claude-sonnet-5): 16777216
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR="'two'**'twenty four'"

echo "concept:    24-bit true color -- 2^24 = 16,777,216 colors"
echo "expression: 'two'**'twenty four'"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
