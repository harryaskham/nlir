#!/usr/bin/env bash
# nlir-golf (aur-2) — "the marathon": how far a marathon is, in words.
#
#     'twenty six' + 'a fifth'
#      └── 26 ──┘     └ 0.2 ┘
#      └──── 26 + 0.2 = 26.2 ────┘
#
# A marathon is 26.2 miles. Coercion reads the whole number and the fraction word
# (a fifth -> 0.2) and adds them: 26.2 -- that famous extra fifth of a mile past
# twenty-six. The exact distance, spelled the way a runner would say it.
#
# Real output (claude-sonnet-5): 26.2
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR="'twenty six'+'a fifth'"

echo "concept:    a marathon = 26.2 miles (twenty-six + a fifth)"
echo "expression: 'twenty six'+'a fifth'   (26 + 0.2)"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
