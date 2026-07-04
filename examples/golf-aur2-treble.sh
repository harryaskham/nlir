#!/usr/bin/env bash
# nlir-golf (aur-2) — "treble twenty": the biggest single dart.
#
#     'twenty' * 'three'
#      └─ 20 ─┘   └ 3 ┘
#      └──── 20 * 3 = 60 ────┘
#
# In darts, the treble ring triples a segment's value, and twenty is the highest
# segment -- so treble twenty scores 20 * 3 = 60, the most a single dart can score.
# Coercion reads both worded numbers and multiplies. The oche's magic number, from words.
#
# Real output (claude-sonnet-5): 60
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR="'twenty'*'three'"

echo "concept:    treble twenty in darts -- 20 * 3 = 60 (max single dart)"
echo "expression: 'twenty'*'three'"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
