#!/usr/bin/env bash
# nlir TARGET-GOLF (aur-2 #80) — reverse game via : (simplify): COMPUTING jargon
# (a checksum) -> plain, 9% shorter.
#
# TARGET (~172 chars):
#   "A checksum is a small number worked out from a chunk of data, sent along with it,
#    so the receiver can recompute it and check nothing got corrupted or changed along
#    the way."
#
# EXPRESSION (156 chars):
#   :'a checksum is a small value computed from a block of data used to detect errors that may have been accidentally introduced during transmission or storage'
#
# Real output (claude-sonnet-5):
#   "A checksum is like a special little number you get by doing math on a bunch of
#    data. It helps you check if the data got messed up or changed by accident while it
#    was being sent or saved somewhere."
# Closeness: same idea (a small number computed from data to detect corruption in
# transit/storage), plain (high), 9% shorter.
#
# (Dropped this tick: ~>'what is a monad' gave a META-summary -- "this text asks for
# an explanation covering..." -- not a definition. A famously-abstract concept tips ~
# into summarising the REQUEST, the same failure class as ~>'how to X'.)
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

TARGET="A checksum is a small number worked out from a chunk of data, sent along with it, so the receiver can recompute it and check nothing got corrupted or changed along the way."
EXPR=":'a checksum is a small value computed from a block of data used to detect errors that may have been accidentally introduced during transmission or storage'"

echo "TARGET (${#TARGET} chars): $TARGET"
echo "EXPR   (${#EXPR} chars): $EXPR"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
