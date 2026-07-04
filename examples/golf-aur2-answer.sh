#!/usr/bin/env bash
# nlir-golf (aur-2) — "the answer": six times seven, spelled out, is 42 -- the
# Answer to Life, the Universe, and Everything.
#
#     'six' * 'seven'
#      └ 6 ┘   └ 7 ┘
#      └── 6 * 7 = 42 ──┘
#
# Coercion reads the two worded numbers and multiplies: 42. Douglas Adams would
# approve. (aur-2 forward #50.)
#
# Real output (claude-sonnet-5): 42
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR="'six'*'seven'"

echo "concept:    the Answer to Life, the Universe, and Everything (6 * 7)"
echo "expression: 'six'*'seven'"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
