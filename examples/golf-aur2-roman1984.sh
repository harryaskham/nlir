#!/usr/bin/env bash
# nlir-golf (aur-2) — "nineteen eighty-four": two Roman numerals, added.
#
#     'MCM' + 'LXXXIV'
#      └1900┘  └ 84 ┘
#      └── 1900 + 84 = 1984 ──┘
#
# Coercion parses BOTH operands as Roman numerals -- MCM is 1900, LXXXIV is 84 --
# and the plus adds them to 1984. Orwell's year, assembled from two ancient numbers.
# (Roman coerces only because the + forces it; a bare 'MCM' stays literal text.)
#
# Real output (claude-sonnet-5): 1984
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR="'MCM'+'LXXXIV'"

echo "concept:    1984 from Roman numerals -- MCM (1900) + LXXXIV (84)"
echo "expression: 'MCM'+'LXXXIV'"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
