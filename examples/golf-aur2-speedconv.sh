#!/usr/bin/env bash
# nlir-golf (aur-2) — "the speed conversion": miles per hour to kilometres per hour.
#
#     'sixty' * '1.6'
#      └ 60 ┘    └ 1.6 ┘
#      └──── 60 * 1.6 = 96 ────┘
#
# A mile is about 1.6 kilometres, so multiplying a speed in mph by 1.6 converts it:
# 60 mph is roughly 96 km/h. Coercion reads the worded number and the decimal side
# by side. A driver's mental-maths trick, in one line.
#
# Real output (claude-sonnet-5): 96
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR="'sixty'*'1.6'"

echo "concept:    mph -> km/h (multiply by ~1.6)"
echo "expression: 'sixty'*'1.6'   (60 * 1.6)"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
