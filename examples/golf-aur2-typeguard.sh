#!/usr/bin/env bash
# nlir-golf (aur-2) — "the type guard": nlir REFUSES an impossible coercion where
# a raw LLM would happily invent an answer.
#
#     1 - [2,3]   -> ERROR: "a list is never a number"
#     [1,2] + 3   -> 6       (the list SPREADS into the variadic +)
#
# Two nearly-identical expressions, opposite fates. `-` is arity-2 (no spread), so
# the list operand must coerce to a number -- and list->number is a HARD type
# error, never guessed. `+` is variadic, so the list SPREADS (1+2+3) instead.
# The deterministic type layer keeps the LLM honest: some things simply are not
# numbers, and nlir says so rather than hallucinating one.
#
# Real output (deterministic, --mode det):
#   1-[2,3] : nlir: cannot coerce list `2|3` to number: a list is never a number
#   [1,2]+3 : 6
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"

echo "concept:    list->number is a HARD error (never guessed); contrast with list-spread"
echo "--- 1-[2,3]  (arity-2 minus: the list cannot coerce to a number) ---"
"$NLIR" --mode det -e '1-[2,3]' 2>&1 || true
echo "--- [1,2]+3  (variadic plus: the list spreads into 1+2+3) ---"
"$NLIR" --mode det -e '[1,2]+3'
