#!/usr/bin/env bash
# nlir-golf (aur-2) — "the BMI": body-mass index, weight over height squared.
#
#     '90' / '1.5' ** '2'
#      └ 90 ┘  └ 1.5 ┘ └ 2 ┘
#      └ 90 / (1.5 ** 2) = 90 / 2.25 = 40 ┘
#
# BMI = weight(kg) / height(m)^2. ** binds tighter than /, so the height is squared
# first (1.5^2 = 2.25), then divided into the weight: a 90 kg person 1.5 m tall has
# a BMI of 40. Precedence does the formula the right way round.
#
# Real output (claude-sonnet-5): 40
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR="'90'/'1.5'**'2'"

echo "concept:    BMI = weight / height^2  (** binds tighter than /)"
echo "expression: '90'/'1.5'**'2'   (90 / 1.5^2)"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
