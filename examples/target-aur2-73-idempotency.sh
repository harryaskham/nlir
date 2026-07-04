#!/usr/bin/env bash
# nlir TARGET-GOLF (aur-2 #73) — reverse game via ~> (summary of expand): a dense
# TECHNICAL one-liner defining an API/distributed-systems property from a 23-char seed.
#
# TARGET (~160 chars):
#   "Idempotency means an operation gives the same result no matter how many times you
#    run it -- so retrying a request (like a payment) won't accidentally do it twice."
#
# EXPRESSION (23 chars):
#   ~>'what is idempotency'
#
# Real output (claude-sonnet-5):
#   "Idempotency is the property where performing an operation multiple times produces
#    the same result as performing it once, a concept used across math, computer
#    science, and API/distributed system design to enable safe retries, reliability,
#    and fault tolerance."
# Closeness: same core (same result however many times you run it -> safe retries),
# and ~> broadens to math/CS/distributed-systems in a deep technical register (high).
# 86% shorter -- 23 characters into a full definition.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

TARGET="Idempotency means an operation gives the same result no matter how many times you run it -- so retrying a request (like a payment) won't accidentally do it twice."
EXPR="~>'what is idempotency'"

echo "TARGET (${#TARGET} chars): $TARGET"
echo "EXPR   (${#EXPR} chars): $EXPR"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
