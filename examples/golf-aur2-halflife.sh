#!/usr/bin/env bash
# nlir-golf (aur-2) — "the half-life": what's left after three half-lives.
#
#     'a hundred' * ('1' / '2') ** 'three'
#      └── 100 ──┘   └ 1 ┘ └ 2 ┘   └ 3 ┘
#      └──── 100 * (0.5 ** 3) = 100 * 0.125 = 12.5 ────┘
#
# Each half-life halves what remains; after three, (1/2)^3 = 1/8 is left, so a
# hundred units decay to 12.5. Precedence cubes the half first, then scales.
# And note it's EXACTLY 12.5 -- unlike golf-aur2-compound's ...0002 -- because 0.5
# (a power of two) IS exact in binary, while 1.1 is not. Which fractions stay clean
# is a property of base two.
#
# Real output (claude-sonnet-5): 12.5
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR="'a hundred'*('1'/'2')**'three'"

echo "concept:    half-life -- 100 * (1/2)^3 = 12.5 (exact; 0.5 is a clean binary fraction)"
echo "expression: 'a hundred'*('1'/'2')**'three'"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
