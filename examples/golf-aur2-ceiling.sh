#!/usr/bin/env bash
# nlir-golf (aur-2) — "the precision ceiling": where exact integers run out.
# The honest companion to the googol (thanks aur-0): nlir numbers are f64, so
# integers are bit-exact only up to 2^53. One step past it, +1 simply vanishes.
#
#     2**52 + 1  => 4503599627370497   (exact: the odd number just above 2^52)
#     2**53 + 1  => 9007199254740992   (== 2**53 !! the +1 is LOST)
#     2**53      => 9007199254740992   (the ceiling)
#
# Below 2^53 every integer (even the odd ones) is representable; AT 2^53 the gap
# between consecutive f64s becomes 2, so 2^53 + 1 rounds back down to 2^53. A crisp
# demonstration of the float precision boundary -- deterministic, offline.
#
# Real output (deterministic, --mode det): see above.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"

echo "concept:    exact integers end at 2^53 (f64); 2**53+1 collapses to 2**53"
echo "--- 2**52+1  (exact, odd) ---";               "$NLIR" --mode det -e '2**52+1'
echo "--- 2**53+1  (== 2**53: the +1 is lost) ---";  "$NLIR" --mode det -e '2**53+1'
echo "--- 2**53    (the ceiling) ---";               "$NLIR" --mode det -e '2**53'
