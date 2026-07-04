#!/usr/bin/env bash
# nlir-golf (aur-2) — "the thermometer": convert Fahrenheit to Celsius with the
# real formula, coercing worded numbers alongside a plain one.
#
#     ( '212' - 'thirty two' ) * 'five' / 'nine'
#       └ 212 ┘  └── 32 ────┘    └ 5 ┘    └ 9 ┘
#       └──── 180 ────┘ * 5 = 900 / 9  =  100
#
# 212 F is water's boiling point; (F - 32) * 5/9 is the F->C formula. "thirty two",
# "five" and "nine" coerce to numbers next to the literal 212, and precedence runs
# the conversion: 212 F = 100 C. A physics formula typed half in words, half digits.
#
# Real output (claude-sonnet-5): 100
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR="('212'-'thirty two')*'five'/'nine'"

echo "concept:    Fahrenheit -> Celsius, (F - 32) * 5/9, over mixed word/digit numbers"
echo "expression: ('212'-'thirty two')*'five'/'nine'   ((212-32)*5/9)"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
