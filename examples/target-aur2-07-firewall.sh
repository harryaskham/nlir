#!/usr/bin/env bash
# nlir TARGET-GOLF (aur-2 #07) — reverse game via ~> (summary of expand): a
# 24-char seed regenerates a full textbook definition in one dense sentence.
#
# TARGET (~132 chars) — a one-line technical definition:
#   "A firewall is a network security system that filters incoming and outgoing traffic against defined rules to block unauthorized access."
#
# EXPRESSION (24 chars):
#   ~>'what a firewall does'
#
# Real output (claude-sonnet-5):
#   "A firewall is a hardware or software security system that filters network
#    traffic between trusted and untrusted networks based on defined rules to
#    block unauthorized access and malicious activity."
# Closeness: same concept, one dense definitional sentence (high). NOTE the
# register: ~> lands a TECHNICAL textbook line; chain : (:~>) if you want it plain.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

TARGET="A firewall is a network security system that filters incoming and outgoing traffic against defined rules to block unauthorized access."
EXPR="~>'what a firewall does'"

echo "TARGET (${#TARGET} chars): $TARGET"
echo "EXPR   (${#EXPR} chars): $EXPR"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
