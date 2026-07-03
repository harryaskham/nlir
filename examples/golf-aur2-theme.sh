#!/usr/bin/env bash
# nlir-golf (aur-2) — "the theme that unifies N documents"
#
# Concept: hand nlir several unrelated-looking documents; get back the single
# theme that unifies them. A depth-3 nested stack over a spread list:
#
#     ~ & [ #d1 , #d2 , #d3 ]
#     │ │   └───┬───┘
#     │ │       └ #  subject of each doc        (3 concurrent LLM calls)
#     │ └───────── &  fluent "and"-join of those subjects   (1 LLM call)
#     └─────────── ~  summarise the joined subjects to one line   (1 LLM call)
#
# 7 structural sigils (~ & [ ] # # #) express "find the common thread across a
# corpus". 5 model calls, 3 of them run concurrently (independent DAG subtrees).
#
# Real output (claude-sonnet-5):
#   Protected bike lanes boost cycling commuting and increase sales at nearby local shops.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

D1='The city council approved new bike lanes downtown to reduce traffic congestion.'
D2='A study found cycling to work lowers stress and improves cardiovascular health.'
D3='Local shops report higher sales on streets with protected bike infrastructure.'

EXPR="~&[#'$D1',#'$D2',#'$D3']"

echo "concept:    the theme that unifies N documents"
echo "sigils:     ~ & [ # # # ]   (7 structural chars, 3 docs)"
echo "expression: ~&[#d1,#d2,#d3]"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
