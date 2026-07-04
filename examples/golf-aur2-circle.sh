#!/usr/bin/env bash
# nlir-golf (aur-2) — "the circle": area = pi * r^2, mixing a decimal, a worded
# radius, and the (now right-associative) power operator.
#
#     '3.14' * 'ten' ** '2'
#      └ 3.14 ┘ └ 10 ┘  └ 2 ┘
#      └ 3.14 * (10 ** 2) = 3.14 * 100 = 314 ┘
#
# ** binds tighter than *, so the radius is squared first (ten^2 = 100), then
# scaled by pi: the area of a circle of radius 10 is about 314. Geometry with the
# radius spelled out as a word.
#
# Real output (claude-sonnet-5): 314
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR="'3.14'*'ten'**'2'"

echo "concept:    area of a circle, pi * r^2, with a worded radius (** > *)"
echo "expression: '3.14'*'ten'**'2'   (3.14 * 10^2)"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
