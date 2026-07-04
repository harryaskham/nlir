#!/usr/bin/env bash
# nlir-golf (aur-2) — "the Roman-numeral calculator": coercion reads Roman
# numerals, then does the maths.
#
#     'MMXXIV' - 'MCMLXXXIV'
#      └─ 2024 ─┘  └─ 1984 ─┘    (each LLM-coerced from Roman to a number)
#      └──── 2024 - 1984 = 40 ────┘
#
# The coercion layer parses Roman numerals (MMXXIV -> 2024) that no ordinary
# calculator accepts, then subtracts exactly: the years between 1984 and 2024.
# General knowledge in, exact arithmetic out.
#
# Real output (claude-sonnet-5): 40
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR="'MMXXIV'-'MCMLXXXIV'"

echo "concept:    arithmetic over Roman numerals (MMXXIV -> 2024)"
echo "expression: 'MMXXIV'-'MCMLXXXIV'   (2024 - 1984)"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
