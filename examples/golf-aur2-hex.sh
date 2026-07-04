#!/usr/bin/env bash
# nlir-golf (aur-2) — "the hex calculator": coercion reads hexadecimal, then does
# the maths in plain decimal.
#
#     '0xFF' - '0x0F'
#      └ 255 ┘  └ 15 ┘    (each hex literal LLM-coerced to its decimal value)
#      └──── 255 - 15 = 240 ────┘
#
# The coercion layer parses 0xFF as 255 and 0x0F as 15 -- base-16 literals no
# calculator input box accepts -- then subtracts exactly. A programmer's pocket
# calculator in two quoted strings.
#
# Real output (claude-sonnet-5): 240
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR="'0xFF'-'0x0F'"

echo "concept:    hexadecimal arithmetic via coercion (0xFF -> 255)"
echo "expression: '0xFF'-'0x0F'   (255 - 15)"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
