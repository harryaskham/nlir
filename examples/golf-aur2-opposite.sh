#!/usr/bin/env bash
# nlir-golf (aur-2) — "the opposite": ! on a bare concept-word gives its ANTONYM.
#
#     !'increase'  => decrease
#     !'hot'       => cold
#
# The negation operator, aimed at a single word rather than a statement, doesn't
# just prepend "not" -- it flips the concept to its opposite. increase -> decrease,
# hot -> cold. A one-sigil antonym finder. (! on a full SENTENCE negates its claim;
# on a lone concept it inverts the concept.)
#
# Real output (claude-sonnet-5):  !'increase' -> decrease ;  !'hot' -> cold
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

echo "concept:    ! on a lone concept-word -> its ANTONYM (the opposite)"
echo "--- !'increase' ---"; "$NLIR" --context-file "$CTX" --mode llm -e "!'increase'"; rm -f "$CTX"
echo "--- !'hot' ---";      "$NLIR" --context-file "$CTX" --mode llm -e "!'hot'"
