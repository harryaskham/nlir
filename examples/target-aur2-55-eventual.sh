#!/usr/bin/env bash
# nlir TARGET-GOLF (aur-2 #55) — reverse game via ~> (summary of expand): a dense
# TECHNICAL one-liner defining a distributed-systems concept from a 55-char seed.
#
# TARGET (~170 chars):
#   "Eventual consistency means that after an update, different copies of the data
#    may disagree for a short while, but if no new changes come in they will all end
#    up the same."
#
# EXPRESSION (55 chars):
#   ~>'what is eventual consistency in distributed systems'
#
# Real output (claude-sonnet-5):
#   "Eventual consistency is a distributed-systems model in which replicas may
#    temporarily diverge or return stale data after a write but are guaranteed to
#    converge to the same value over time, trading immediate accuracy... for
#    availability, fault tolerance, and performance... like DNS, CDNs, NoSQL."
# Closeness: same core (replicas diverge then converge), but ~> lands DEEP technical
# register (CAP theorem, strong-consistency tradeoff, real examples) (high). 68% shorter.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

TARGET="Eventual consistency means that after an update, different copies of the data may disagree for a short while, but if no new changes come in they will all end up the same."
EXPR="~>'what is eventual consistency in distributed systems'"

echo "TARGET (${#TARGET} chars): $TARGET"
echo "EXPR   (${#EXPR} chars): $EXPR"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
