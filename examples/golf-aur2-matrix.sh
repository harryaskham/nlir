#!/usr/bin/env bash
# nlir-golf (aur-2) — "the options matrix": nest OR inside AND to frame a
# combinatorial choice as one clean line.
#
#     ~ & [ |[a,b] , |[c,d] ]
#     │ │    │        │
#     │ │    │        └ or-join the second axis (c or d)
#     │ │    └───────── or-join the first axis (a or b)
#     │ └────────────── & and-join the two axes
#     └──────────────── ~ summarise into one tidy line
#
# 7 structural sigils express a 2-axis decision space (a-or-b AND c-or-d) --
# nested mixfix, OR within AND, distilled.
#
# Real output (claude-sonnet-5) for
#   [|['cash','card'], |['pickup','delivery']]:
#   Payment (cash or card) and fulfillment (pickup or delivery) options.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR="~&[|['cash','card'],|['pickup','delivery']]"

echo "concept:    a 2-axis combinatorial choice, framed in one line"
echo "sigils:     ~ & [ |[ ] , |[ ] ]   (nested OR-in-AND)"
echo "expression: ~&[|[a,b],|[c,d]]"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
