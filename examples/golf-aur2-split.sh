#!/usr/bin/env bash
# nlir-golf (aur-2) — "the semantic bill splitter": a real-world word problem in
# fuzzy quantities, solved with coercion + grouping + division.
#
#     ( 'a hundred' + 'a score' ) / 'a handful'
#        └── 100 ──┘  └── 20 ──┘     └── 5 ──┘    (each LLM-coerced to a number)
#        └──────── 120 ─────────┘  ÷   5   =  24
#
# "Split a $120-ish bill among a handful of people." Words in, exact money out.
# Grouping forces the add before the divide; coercion supplies the numbers.
#
# Real output (claude-sonnet-5): 24
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR="('a hundred'+'a score')/'a handful'"

echo "concept:    split a fuzzy total among a fuzzy number of people"
echo "expression: ('a hundred'+'a score')/'a handful'   ((100+20)/5)"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
