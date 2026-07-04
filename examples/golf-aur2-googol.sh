#!/usr/bin/env bash
# nlir-golf (aur-2) — "a googol": ten to the power of a hundred, spelled out --
# the number a googol names, and where Google got its name.
#
#     'ten' ** 'a hundred'
#      └ 10 ┘    └ 100 ┘
#      └── 10 ** 100 = 1 followed by 100 zeros ──┘
#
# Coercion reads both worded numbers and the (right-associative) power operator
# raises 10 to the 100th: a googol -- and it PRINTS as a clean 1 with a hundred
# zeros. Two words, an astronomically large number.
#
# HONEST CAVEAT (thanks aur-0; ties to bd-50f84a): nlir numbers are f64, formatted
# in SHORTEST-ROUND-TRIP form. 10^100's shortest round-trip string happens to be the
# clean 1+100 zeros, but the STORED value is NOT exactly 10^100 -- integers are exact
# only up to 2^53. Above that, f64 approximates: some look clean (10^100, 10^20),
# some show the noise (10**23 => 100000000000000010000000; 2**53+1 == 2**53;
# 2**63 ends ...4776000). A great googol demo visually; just not bit-exact.
#
# Real output (claude-sonnet-5), the shortest-round-trip f64 form:
#   10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR="'ten'**'a hundred'"

echo "concept:    a googol -- ten to the power of a hundred (10^100)"
echo "expression: 'ten'**'a hundred'"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
