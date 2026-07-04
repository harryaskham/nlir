#!/usr/bin/env bash
# nlir TARGET-GOLF (aur-2 #11) — reverse game via ~> (summary of expand): a 24-char
# seed regenerates a full one-sentence technical definition (cf. #07 firewall).
#
# TARGET (99 chars):
#   "Encryption is the process of scrambling data so that only someone with the correct key can read it."
#
# EXPRESSION (24 chars):
#   ~>'what encryption does'
#
# Real output (claude-sonnet-5):
#   "Encryption uses a secret key and algorithm to convert readable data into
#    unreadable ciphertext, protecting its confidentiality while still allowing
#    authorized users to decrypt and read it."
# Closeness: same concept (key; unreadable; only authorized read), one dense
# technical sentence (high); 76% shorter. ~> = expand for richness, ~ for fit.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

TARGET="Encryption is the process of scrambling data so that only someone with the correct key can read it."
EXPR="~>'what encryption does'"

echo "TARGET (${#TARGET} chars): $TARGET"
echo "EXPR   (${#EXPR} chars): $EXPR"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
