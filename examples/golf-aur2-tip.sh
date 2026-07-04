#!/usr/bin/env bash
# nlir-golf (aur-2) — "the tip calculator": a bill plus a percentage tip, in
# words, via coercion + precedence.
#
#     'sixty' + 'sixty' * 'a fifth'
#      └─ 60 ─┘   └─ 60 ─┘  └─ 0.2 ─┘   (each LLM-coerced; "a fifth" -> 0.2)
#                  └── 60 * 0.2 = 12 (the 20% tip) ──┘
#      └────────── 60 + 12 = 72 (bill + tip) ──────────┘
#
# "a fifth" coerces to the FRACTION 0.2, and precedence does the tip before the
# add: a $60 bill plus a 20% tip is $72. Words in, exact total out.
#
# Real output (claude-sonnet-5): 72
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR="'sixty'+'sixty'*'a fifth'"

echo "concept:    a bill plus a 20% tip, written in words"
echo "expression: 'sixty'+'sixty'*'a fifth'   (60 + 60*0.2)"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
