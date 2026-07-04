#!/usr/bin/env bash
# nlir TARGET-GOLF (aur-2 #45) — reverse game via : (simplify): COMPUTING jargon
# -> plain, and : reaches for a kids-with-toys analogy on its own.
#
# TARGET (~133 chars):
#   "A deadlock is when two programs freeze because each one is waiting for the
#    other to let go of something first, so neither ever moves."
#
# EXPRESSION (129 chars):
#   :'a deadlock is a situation where two processes are each waiting for the other to release a resource so neither can ever proceed'
#
# Real output (claude-sonnet-5):
#   "A deadlock is like when two kids each have a toy the other one wants. Each kid
#    says, 'I'll trade you, but you go first!' Since neither one wants to go first,
#    they both just stand there forever, and nobody gets to play."
# Closeness: same mechanism (mutual waiting -> nobody proceeds), plain + its own
# kids-with-toys analogy (high). : turns a concurrency bug into a playground story.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

TARGET="A deadlock is when two programs freeze because each one is waiting for the other to let go of something first, so neither ever moves."
EXPR=":'a deadlock is a situation where two processes are each waiting for the other to release a resource so neither can ever proceed'"

echo "TARGET (${#TARGET} chars): $TARGET"
echo "EXPR   (${#EXPR} chars): $EXPR"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
