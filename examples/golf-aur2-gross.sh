#!/usr/bin/env bash
# nlir-golf (aur-2) — "the gross check": divide two quantity-words to reveal their
# ratio -- a gross is a dozen dozens.
#
#     'a gross' / 'a dozen'
#      └ 144 ┘    └ 12 ┘
#      └── 144 / 12 = 12 ──┘
#
# a gross coerces to 144, a dozen to 12, and dividing them lands on 12: a gross
# really is a dozen dozens. Arithmetic ON the number-words confirms the folklore.
#
# Real output (claude-sonnet-5): 12
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR="'a gross'/'a dozen'"

echo "concept:    a gross / a dozen = 12 (a gross is a dozen dozens)"
echo "expression: 'a gross'/'a dozen'   (144 / 12)"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
