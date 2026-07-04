#!/usr/bin/env bash
# nlir-golf (aur-2) — "the coercion cascade": exact digits and fuzzy words summed
# in one expression, each taking a DIFFERENT coercion path.
#
#     + [ '5' , 'five' , 'a handful' ]
#         └5┘   └─ 5 ─┘  └──── 5 ────┘
#          │       └──────────┴── LLM coercion (words -> numbers)
#          └── deterministic parse ("5" is already a number, no model call)
#     └──────── 5 + 5 + 5 = 15 ────────┘
#
# nlir's coercion tries the DETERMINISTIC parse first ("5" needs no model), then
# falls back to the LLM for the words -- so exact and fuzzy numbers add together
# seamlessly. The type machinery, on show in one sum.
#
# Real output (claude-sonnet-5): 15
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR="+['5','five','a handful']"

echo "concept:    mix exact digits + fuzzy words (deterministic + LLM coercion)"
echo "expression: +['5','five','a handful']   (5 + 5 + 5)"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
