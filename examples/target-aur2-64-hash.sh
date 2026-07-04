#!/usr/bin/env bash
# nlir TARGET-GOLF (aur-2 #64) — reverse game via ~> (summary of expand): a dense
# TECHNICAL one-liner defining a crypto/CS primitive from a 27-char seed.
#
# TARGET (~189 chars):
#   "A hash function takes any input and scrambles it into a short fixed-size string
#    of characters, where the same input always gives the same output but you can't
#    work backwards to the original."
#
# EXPRESSION (27 chars):
#   ~>'what is a hash function'
#
# Real output (claude-sonnet-5):
#   "A hash function is a deterministic, one-way algorithm that converts input of any
#    size into a fixed-size value, and good ones exhibit the avalanche effect and few
#    collisions, enabling uses like hash tables, data integrity checks, password
#    storage, and cryptographic applications such as digital signatures and blockchain."
# Closeness: same core (any input -> deterministic fixed-size, one-way), but ~> lands
# DEEP technical register (avalanche effect, collisions, use cases) (high). 86% shorter.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

TARGET="A hash function takes any input and scrambles it into a short fixed-size string of characters, where the same input always gives the same output but you can't work backwards to the original."
EXPR="~>'what is a hash function'"

echo "TARGET (${#TARGET} chars): $TARGET"
echo "EXPR   (${#EXPR} chars): $EXPR"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
