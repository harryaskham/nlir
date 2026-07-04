#!/usr/bin/env bash
# nlir-golf (aur-2) — "wheat & chessboard": one grain, doubled sixty-four times.
#
#     'two' ** 'sixty four'
#      └ 2 ┘    └── 64 ──┘
#      └──── 2 ** 64 ────┘
#
# The old legend: a grain on the first square, doubled each square, is 2^64 grains on
# the 64th -- more wheat than the world has ever grown. Coercion + the power operator
# compute it. HONEST f64 caveat: 2^64 = 18,446,744,073,709,551,616 exactly, but that's
# past 2^53 (a double's exact-integer ceiling), so nlir prints 18446744073709552000 --
# right to ~16 significant figures, rounded in the last digits (cf. golf-aur2-googol /
# -ceiling, bd-50f84a).
#
# Real output (claude-sonnet-5): 18446744073709552000
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR="'two'**'sixty four'"

echo "concept:    wheat & chessboard -- 2^64 grains (f64: rounded past 2^53)"
echo "expression: 'two'**'sixty four'"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
