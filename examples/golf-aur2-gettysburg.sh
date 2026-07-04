#!/usr/bin/env bash
# nlir-golf (aur-2) — "four score and seven": Lincoln's arithmetic, computed.
#
#     'eighteen sixty three' - 'four score and seven'
#      └──── 1863 ────┘         └── 4*20 + 7 = 87 ──┘
#      └──────── 1863 - 87 = 1776 ────────┘
#
# The Gettysburg Address opens "four score and seven years ago" -- spoken in 1863.
# Coercion reads BOTH worded numbers (eighteen sixty three -> 1863, four score and
# seven -> 87) and the subtraction lands on 1776: the year Lincoln's phrase was
# pointing at, the signing of the Declaration of Independence. The archaic number
# words do real history.
#
# (Note: a BARE 'four score and seven' is left as a literal string -- coercion only
#  fires when an arithmetic operator forces it, as the subtraction does here.)
#
# Real output (claude-sonnet-5): 1776
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR="'eighteen sixty three'-'four score and seven'"

echo "concept:    Gettysburg arithmetic -- 1863 minus 'four score and seven' (87) = 1776"
echo "expression: 'eighteen sixty three'-'four score and seven'"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
