#!/usr/bin/env bash
# nlir-golf (aur-2) — "threescore and ten": three score, plus ten.
#
#     'three score' + 'ten'
#      └─── 60 ────┘   └ 10 ┘
#      └──── 60 + 10 = 70 ────┘
#
# A "score" is twenty, so "three score" is sixty; plus ten makes seventy -- the
# biblical span of a human life ("threescore years and ten", Psalm 90). Coercion
# reads the archaic multiplier-phrase, and the plus finishes it.
#
# Real output (claude-sonnet-5): 70
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR="'three score'+'ten'"

echo "concept:    threescore and ten -- 3*20 + 10 = 70 (a human lifespan)"
echo "expression: 'three score'+'ten'"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
