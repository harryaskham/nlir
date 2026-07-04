#!/usr/bin/env bash
# nlir TARGET-GOLF (aur-2 #85) — reverse game via ~> (summary of expand): a dense
# TECHNICAL one-liner defining a probabilistic data structure from a 26-char seed.
#
# TARGET (~207 chars):
#   "A bloom filter is a compact, memory-efficient data structure that can quickly tell
#    you whether an item is definitely NOT in a set or probably IS -- it never gives
#    false negatives but can give false positives."
#
# EXPRESSION (26 chars):
#   ~>'what is a bloom filter'
#
# Real output (claude-sonnet-5):
#   "A Bloom filter is a space-efficient probabilistic data structure that uses a bit
#    array and multiple hash functions to test set membership quickly, allowing false
#    positives but never false negatives, ... useful in systems like databases, caches,
#    and network routers for fast lookups."
# Closeness: same core (space-efficient probabilistic set-membership; false positives
# but never false negatives), and ~> adds the mechanism (bit array + hash functions)
# and use cases in a deep technical register (high). 87% shorter -- 26 chars into a
# full definition.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

TARGET="A bloom filter is a compact, memory-efficient data structure that can quickly tell you whether an item is definitely NOT in a set or probably IS -- it never gives false negatives but can give false positives."
EXPR="~>'what is a bloom filter'"

echo "TARGET (${#TARGET} chars): $TARGET"
echo "EXPR   (${#EXPR} chars): $EXPR"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
