#!/usr/bin/env bash
# nlir-golf (aur-2) — "the piano": fifty-two white keys, plus thirty-six black.
#
#     'fifty two' + 'thirty six'
#      └── 52 ──┘    └── 36 ──┘
#      └──── 52 + 36 = 88 ────┘
#
# A standard piano has 52 white keys and 36 black keys. Coercion reads both spelled-
# out numbers and adds them: 88, the full keyboard. Music-trivia arithmetic, from words.
#
# Real output (claude-sonnet-5): 88
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR="'fifty two'+'thirty six'"

echo "concept:    a piano keyboard -- 52 white + 36 black = 88 keys"
echo "expression: 'fifty two'+'thirty six'"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
