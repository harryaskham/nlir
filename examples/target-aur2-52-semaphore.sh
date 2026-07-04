#!/usr/bin/env bash
# nlir TARGET-GOLF (aur-2 #52) — reverse game via ~> (summary of expand): a dense
# TECHNICAL one-liner defining a concurrency primitive from a 38-char seed.
#
# TARGET (~135 chars):
#   "A semaphore is a counter that controls how many processes can use a shared
#    resource at once, blocking any extras until a slot frees up."
#
# EXPRESSION (38 chars):
#   ~>'what is a semaphore in programming'
#
# Real output (claude-sonnet-5):
#   "A semaphore is a synchronization primitive using a counter and atomic
#    wait/signal operations to control concurrent access to shared resources,
#    preventing race conditions... binary and counting forms... thread pools,
#    connection limiting, and producer-consumer coordination."
# Closeness: same core (a counter gating concurrent access to a shared resource),
# but ~> lands DEEP technical register (atomic wait/signal, binary/counting) (high).
# 72% shorter. (For a plainer phrasing, use :~>.)
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

TARGET="A semaphore is a counter that controls how many processes can use a shared resource at once, blocking any extras until a slot frees up."
EXPR="~>'what is a semaphore in programming'"

echo "TARGET (${#TARGET} chars): $TARGET"
echo "EXPR   (${#EXPR} chars): $EXPR"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
