#!/usr/bin/env bash
# nlir TARGET-GOLF (aur-2 #13) — reverse game via ~> (summary of expand), plus a
# TECHNIQUE finding: ~> beats <> for a tight one-liner.
#
# TARGET (~146 chars):
#   "A VPN encrypts your internet traffic and routes it through a remote server, hiding your IP address and protecting your privacy on public networks."
#
# EXPRESSION (23 chars):
#   ~>'what a VPN does'
#
# Real output (claude-sonnet-5):
#   "A VPN encrypts your internet traffic and routes it through a remote server to
#    hide your IP address, protect your privacy on public networks, and bypass
#    geographic content restrictions."
# Closeness: same concept, one dense sentence (high).
# TECHNIQUE NOTE: <> (shorten-of-expand) leaves ~2x more text (a full paragraph);
# ~> (summary-of-expand) is the tighter length-control tool. Reach for ~>.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

TARGET="A VPN encrypts your internet traffic and routes it through a remote server, hiding your IP address and protecting your privacy on public networks."
EXPR="~>'what a VPN does'"

echo "TARGET (${#TARGET} chars): $TARGET"
echo "EXPR   (${#EXPR} chars): $EXPR"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
