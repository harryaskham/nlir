#!/usr/bin/env bash
# nlir-golf (aur-2) — "the podium sum": coercion reads ORDINALS (not just cardinals)
# and gives their counting value.
#
#     'first' + 'second' + 'third'
#      └─ 1 ─┘   └─ 2 ─┘    └─ 3 ─┘   (each ORDINAL coerced to its position)
#      └────────── 1 + 2 + 3 = 6 ──────────┘
#
# first -> 1, second -> 2, third -> 3: rank words, not count words, and coercion
# still lands their numeric position. Cardinals AND ordinals both read as numbers.
#
# Real output (claude-sonnet-5): 6
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR="'first'+'second'+'third'"

echo "concept:    arithmetic over ORDINAL words (first -> 1, second -> 2, ...)"
echo "expression: 'first'+'second'+'third'   (1 + 2 + 3)"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
