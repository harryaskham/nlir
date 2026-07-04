#!/usr/bin/env bash
# nlir-golf (aur-2) — "the reel": how many frames in a 90-minute film.
#
#     'twenty four' * 'sixty' * 'ninety'
#      └── 24 ────┘   └ 60 ┘   └── 90 ──┘
#      └──── 24 * 60 * 90 = 129600 ────┘
#
# Film runs at 24 frames a second; sixty seconds a minute, ninety minutes a feature.
# So a 90-minute film is 24 * 60 * 90 = 129,600 individual frames. Coercion reads the
# three worded numbers and multiplies. Every still that flickers past, counted.
#
# Real output (claude-sonnet-5): 129600
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR="'twenty four'*'sixty'*'ninety'"

echo "concept:    frames in a 90-min film -- 24fps * 60s * 90min = 129,600"
echo "expression: 'twenty four'*'sixty'*'ninety'"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
