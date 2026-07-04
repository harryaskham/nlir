#!/usr/bin/env bash
# nlir TARGET-GOLF (aur-2 #82) — reverse game via ~> (summary of expand): a dense
# TECHNICAL one-liner defining a distributed-systems concept from a 24-char seed.
#
# TARGET (~201 chars):
#   "Backpressure is when a system that can't keep up with incoming work signals the
#    sender to slow down, so a fast producer doesn't overwhelm a slower consumer and
#    cause queues to blow up or things to crash."
#
# EXPRESSION (24 chars):
#   ~>'what is backpressure'
#
# Real output (claude-sonnet-5):
#   "Backpressure is a flow-control mechanism -- borrowed from physical systems and
#    applied in computing -- that lets a slow consumer signal a fast producer to slow
#    down, preventing overflow, memory exhaustion, or data loss when processing speeds
#    mismatch."
# Closeness: same core (a slow consumer signals a fast producer to slow down -> prevent
# overflow/crash), and ~> adds the framing (flow-control, physical-systems origin,
# memory exhaustion) in a technical register (high). 88% shorter -- 24 chars into a
# full definition. (Fitting: the daemon backpressure this session is the same idea.)
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

TARGET="Backpressure is when a system that can't keep up with incoming work signals the sender to slow down, so a fast producer doesn't overwhelm a slower consumer and cause queues to blow up or things to crash."
EXPR="~>'what is backpressure'"

echo "TARGET (${#TARGET} chars): $TARGET"
echo "EXPR   (${#EXPR} chars): $EXPR"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
