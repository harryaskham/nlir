#!/usr/bin/env bash
# nlir TARGET-GOLF (aur-2 #94) — reverse game via ~> (summary of expand): a dense
# TECHNICAL one-liner defining a concurrency primitive from a 19-char seed.
#
# TARGET (~201 chars):
#   "A mutex is a lock that lets only one thread use a shared resource at a time -- a
#    thread must acquire it before touching the resource and release it after, so two
#    threads can't clash and corrupt the data."
#
# EXPRESSION (19 chars):
#   ~>'what is a mutex'
#
# Real output (claude-sonnet-5):
#   "A mutex is a synchronization primitive that ensures only one thread or process can
#    access a shared resource or critical section at a time, preventing race conditions
#    in concurrent programming."
# Closeness: same core (a lock ensuring one thread at a time on a shared resource ->
# prevents race conditions), high; ~> lands the textbook terms ("synchronization
# primitive", "critical section"). 91% shorter -- 19 chars into a full definition.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

TARGET="A mutex is a lock that lets only one thread use a shared resource at a time -- a thread must acquire it before touching the resource and release it after, so two threads can't clash and corrupt the data."
EXPR="~>'what is a mutex'"

echo "TARGET (${#TARGET} chars): $TARGET"
echo "EXPR   (${#EXPR} chars): $EXPR"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
