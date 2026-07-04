#!/usr/bin/env bash
# nlir TARGET-GOLF (aur-2 #28) — reverse game via ~> (summary of expand): a
# one-line definition of a modern tech term from a 28-char seed.
#
# TARGET (~134 chars):
#   "A smart contract is a program stored on a blockchain that automatically runs when its conditions are met, without needing a middleman."
#
# EXPRESSION (28 chars):
#   ~>'what is a smart contract'
#
# Real output (claude-sonnet-5):
#   "A smart contract is a self-executing piece of code running on a blockchain that
#    automatically enforces and carries out an agreement's terms when predefined
#    conditions are met, without relying on courts or intermediaries."
# Closeness: same concept (self-executing code on a blockchain, runs on conditions,
# no middleman), one dense sentence (high). 79% shorter.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

TARGET="A smart contract is a program stored on a blockchain that automatically runs when its conditions are met, without needing a middleman."
EXPR="~>'what is a smart contract'"

echo "TARGET (${#TARGET} chars): $TARGET"
echo "EXPR   (${#EXPR} chars): $EXPR"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
