#!/usr/bin/env bash
# nlir TARGET-GOLF (aur-2 #50) — reverse game via : (simplify): LINGUISTICS jargon
# -> plain, keeping both worked examples.
#
# TARGET (~143 chars):
#   "A palindrome is a word or phrase that reads exactly the same forwards and
#    backwards, like the word 'level' or the sentence 'never odd or even'."
#
# EXPRESSION (139 chars):
#   :'a palindrome is a word phrase or sequence that reads the same backward as forward such as the word level or the phrase never odd or even'
#
# Real output (claude-sonnet-5):
#   "A palindrome is a word or a group of words that reads the same way whether you
#    go forward or backward. Like the word 'level' ... Or the phrase 'never odd or
#    even' ..."
# Closeness: same definition + both examples (level / never odd or even) kept, plain
# register (high), ~even length. A register/clarity play.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

TARGET="A palindrome is a word or phrase that reads exactly the same forwards and backwards, like the word 'level' or the sentence 'never odd or even'."
EXPR=":'a palindrome is a word phrase or sequence that reads the same backward as forward such as the word level or the phrase never odd or even'"

echo "TARGET (${#TARGET} chars): $TARGET"
echo "EXPR   (${#EXPR} chars): $EXPR"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
