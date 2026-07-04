#!/usr/bin/env bash
# nlir-golf (aur-2) — "the collective-noun calculator": coercion knows the words
# for small groups, then adds them.
#
#     'half a dozen' + 'a pair' + 'a trio'
#      └──── 6 ────┘   └─ 2 ─┘    └─ 3 ─┘   (collective words coerced to counts)
#      └────────── 6 + 2 + 3 = 11 ──────────┘
#
# a pair -> 2, a trio -> 3, half a dozen -> 6: quantity words a calculator has
# never heard of, summed exactly. General knowledge in, exact arithmetic out.
#
# Real output (claude-sonnet-5): 11
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR="'half a dozen'+'a pair'+'a trio'"

echo "concept:    arithmetic over collective-number words (pair/trio/half-a-dozen)"
echo "expression: 'half a dozen'+'a pair'+'a trio'   (6+2+3)"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
