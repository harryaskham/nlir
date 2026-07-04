#!/usr/bin/env bash
# nlir TARGET-GOLF (aur-2 #104) — reverse game via ~> (summary of expand): a dense
# TECHNICAL one-liner defining a distributed-systems concept from a 27-char seed.
#
# TARGET (~225 chars):
#   "A message queue is a buffer that lets different parts of a system talk asynchronously:
#    senders drop messages into the queue and receivers pick them up when ready, so the two
#    sides do not have to be available at the same time."
#
# EXPRESSION (27 chars):
#   ~>'what is a message queue'
#
# Real output (claude-sonnet-5):
#   "A message queue is an intermediary that stores messages between producers and
#    consumers, enabling asynchronous, decoupled, and reliable communication in distributed
#    systems."
# Closeness: same core (buffer/intermediary between senders and receivers, asynchronous +
# decoupled), technical register (high), 88% shorter -- 27 chars into a full definition.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

TARGET="A message queue is a buffer that lets different parts of a system talk asynchronously: senders drop messages into the queue and receivers pick them up when ready, so the two sides do not have to be available at the same time."
EXPR="~>'what is a message queue'"

echo "TARGET (${#TARGET} chars): $TARGET"
echo "EXPR   (${#EXPR} chars): $EXPR"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
