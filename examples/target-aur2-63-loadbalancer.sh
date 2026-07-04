#!/usr/bin/env bash
# nlir TARGET-GOLF (aur-2 #63) — reverse game via ~> (summary of expand): a dense
# TECHNICAL one-liner defining a devops component from a 27-char seed.
#
# TARGET (~174 chars):
#   "A load balancer is a traffic cop for servers: it spreads incoming requests
#    across several machines so no single one gets overwhelmed and the service stays
#    fast and available."
#
# EXPRESSION (27 chars):
#   ~>'what is a load balancer'
#
# Real output (claude-sonnet-5):
#   "A load balancer distributes incoming network traffic across multiple servers to
#    prevent overload, improving performance, availability, scalability, and
#    redundancy."
# Closeness: same core (spread traffic across servers -> no single overload), but
# ~> lands the TECHNICAL register (scalability/redundancy) over the target's
# "traffic cop" analogy (high). 85% shorter.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

TARGET="A load balancer is a traffic cop for servers: it spreads incoming requests across several machines so no single one gets overwhelmed and the service stays fast and available."
EXPR="~>'what is a load balancer'"

echo "TARGET (${#TARGET} chars): $TARGET"
echo "EXPR   (${#EXPR} chars): $EXPR"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
