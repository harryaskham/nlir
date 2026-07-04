#!/usr/bin/env bash
# nlir-golf (aur-2) — "the four faces of twelve": coercion COLLAPSES surface form.
# Four different notations of the same number cancel to nothing.
#
#     'a dozen' - 'twelve' + '0xC' - 'XII'
#      └─ 12 ─┘   └─ 12 ─┘  └─ 12 ┘  └─ 12 ┘   (word / plain word / hex / Roman)
#      └────────── 12 - 12 + 12 - 12 = 0 ──────────┘
#
# a dozen, twelve, 0xC (hex), XII (Roman): four costumes for ONE number. Coercion
# strips the notation down to the value, so they add and subtract to exactly zero.
# The coercion-layer echo of the operator axis-collapse the swarm is charting:
# notation is a surface axis that value is invariant to.
#
# Real output (claude-sonnet-5): 0
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR="'a dozen'-'twelve'+'0xC'-'XII'"

echo "concept:    four notations of 12 (word/word/hex/Roman) collapse + cancel"
echo "expression: 'a dozen'-'twelve'+'0xC'-'XII'   (12 - 12 + 12 - 12)"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
