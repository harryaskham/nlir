#!/usr/bin/env bash
# nlir-golf (aur-2) — "the category": name what a list of things have in common.
#
#     # ( ~ & [ 'a violin', 'a cello', 'a guitar' ] )
#     └subject┘└summary┘└──── join the list ────┘
#
# & joins the three items, ~ summarises the joined set, and # names the SUBJECT of
# that summary -- the category they all belong to: "Musical instruments". A one-line
# classifier: list some examples, get the class they share.
#
# Real output (claude-sonnet-5): Musical instruments
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR="#~&['a violin','a cello','a guitar']"

echo "concept:    #~& over a list names the CATEGORY the items share"
echo "expression: #~&['a violin','a cello','a guitar']"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
