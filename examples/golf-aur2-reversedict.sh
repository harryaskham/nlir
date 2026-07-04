#!/usr/bin/env bash
# nlir-golf (aur-2) — "the reverse dictionary": describe a thing, # names it.
#
#     # 'a program that translates source code into machine code'
#     └subject┘└──────── the description ────────┘
#
# # extracts the SUBJECT of a description -- the single word the whole phrase is
# defining. Feed it what something DOES, get back what it's CALLED: "Compiler".
# A dictionary run backwards. (Distinct from #~& over a LIST, which names a shared
# category; this is # on a single DESCRIPTION.)
#
# Real output (claude-sonnet-5): Compiler
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR="#'a program that translates source code into machine code'"

echo "concept:    # on a DESCRIPTION names the thing (a reverse dictionary)"
echo "expression: #'a program that translates source code into machine code'"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
