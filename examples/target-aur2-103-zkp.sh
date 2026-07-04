#!/usr/bin/env bash
# nlir TARGET-GOLF (aur-2 #103) — reverse game via : (simplify): CRYPTOGRAPHY jargon
# (zero-knowledge proof) -> plain, 21% shorter.
#
# TARGET (~202 chars):
#   "A zero-knowledge proof is a way for one person to prove to another that something is
#    true, without revealing anything else about it -- you convince them you know a secret
#    without ever showing the secret."
#
# EXPRESSION (160 chars):
#   :'a zero-knowledge proof lets one party prove to another that a statement is true without revealing any information beyond the validity of the statement itself'
#
# Real output (claude-sonnet-5):
#   "A zero-knowledge proof is a way for someone to show they know a secret or that
#    something is true, without actually telling what the secret is. It's like proving you
#    know the answer to a puzzle without saying the answer out loud."
# Closeness: same idea (prove a statement true without revealing the secret), plain +
# a puzzle-answer analogy (high), 21% shorter.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

TARGET="A zero-knowledge proof is a way for one person to prove to another that something is true, without revealing anything else about it -- you convince them you know a secret without ever showing the secret."
EXPR=":'a zero-knowledge proof lets one party prove to another that a statement is true without revealing any information beyond the validity of the statement itself'"

echo "TARGET (${#TARGET} chars): $TARGET"
echo "EXPR   (${#EXPR} chars): $EXPR"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
