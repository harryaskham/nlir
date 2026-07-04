#!/usr/bin/env bash
# nlir TARGET-GOLF (aur-2 #62) — reverse game via : (simplify): LEGAL/business jargon
# (an NDA) -> plain.
#
# TARGET (~148 chars):
#   "An NDA is a contract where you promise not to share a company's private
#    information -- trade secrets, plans, that kind of thing -- with anyone outside."
#
# EXPRESSION (149 chars):
#   :'a non-disclosure agreement is a legal contract that prevents someone from sharing confidential information they learn while working with a company'
#
# Real output (claude-sonnet-5):
#   "A non-disclosure agreement is a special promise you sign. It says you won't tell
#    anyone the secret things you learn while working with a company."
# Closeness: same idea (a signed promise not to reveal a company's confidential
# info), plain (high), ~even length. A register/clarity play.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

TARGET="An NDA is a contract where you promise not to share a company's private information -- trade secrets, plans, that kind of thing -- with anyone outside."
EXPR=":'a non-disclosure agreement is a legal contract that prevents someone from sharing confidential information they learn while working with a company'"

echo "TARGET (${#TARGET} chars): $TARGET"
echo "EXPR   (${#EXPR} chars): $EXPR"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
