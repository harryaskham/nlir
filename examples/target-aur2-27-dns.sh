#!/usr/bin/env bash
# nlir TARGET-GOLF (aur-2 #27) — reverse game via : (simplify): NETWORKING jargon
# -> plain, and : reaches for the classic "phonebook" analogy on its own.
#
# TARGET (~122 chars):
#   "DNS is the internet phonebook: it turns a website name you type into the numeric address computers use to find each other."
#
# EXPRESSION (91 chars):
#   :'DNS translates a human-readable domain name into the numeric IP address a computer needs'
#
# Real output (claude-sonnet-5):
#   "DNS is like a phone book for the internet. It turns website names people can
#    read, like 'google.com', into number codes that computers use to find each other."
# Closeness: same analogy (internet phonebook) + a concrete example (google.com),
# plain register (high). : lands the intended metaphor and grounds it.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

TARGET="DNS is the internet phonebook: it turns a website name you type into the numeric address computers use to find each other."
EXPR=":'DNS translates a human-readable domain name into the numeric IP address a computer needs'"

echo "TARGET (${#TARGET} chars): $TARGET"
echo "EXPR   (${#EXPR} chars): $EXPR"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
