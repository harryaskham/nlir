#!/usr/bin/env bash
# nlir-golf (aur-2) — "the whole": two fraction-words that complete to exactly one.
#
#     'three quarters' + 'a quarter'
#      └── 0.75 ──┘      └ 0.25 ┘
#      └──── 0.75 + 0.25 = 1 ────┘
#
# a quarter -> 0.25, three quarters -> 0.75: coercion reads the fraction words and
# they add to exactly 1 -- the missing quarter completes the whole. Fractions in
# plain English, summed to a round number.
#
# Real output (claude-sonnet-5): 1
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR="'three quarters'+'a quarter'"

echo "concept:    fraction-words completing to a whole (0.75 + 0.25 = 1)"
echo "expression: 'three quarters'+'a quarter'"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
