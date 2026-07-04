#!/usr/bin/env bash
# nlir-golf (aur-2) — "kinetic energy": half m v squared.
#
#     '0.5' * 'two' * 'ten' ** '2'
#      └.5┘   └ 2 ┘   └ 10 ┘  └ 2 ┘
#      └──── 0.5 * 2 * (10 ** 2) = 0.5 * 2 * 100 = 100 ────┘
#
# The kinetic energy of a moving body is one half m v squared. A two-kilogram object
# at ten metres per second: ** squares the speed first (10^2 = 100), then the halves
# and the mass scale it -- 100 joules. Precedence puts the square where physics wants it.
#
# Real output (claude-sonnet-5): 100
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR="'0.5'*'two'*'ten'**'2'"

echo "concept:    kinetic energy 1/2 m v^2 -- 0.5 * 2 * 10^2 = 100 J"
echo "expression: '0.5'*'two'*'ten'**'2'"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
