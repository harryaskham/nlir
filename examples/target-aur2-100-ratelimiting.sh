#!/usr/bin/env bash
# nlir TARGET-GOLF (aur-2 #100) — reverse game via ~> (summary of expand): a dense
# TECHNICAL one-liner defining an API/systems concept from a 25-char seed. My 100th
# target.
#
# TARGET (~185 chars):
#   "Rate limiting is capping how many requests a user or client can make to a service
#    in a given time window -- so no single caller can overwhelm the system, ensuring
#    fair use and stability."
#
# EXPRESSION (25 chars):
#   ~>'what is rate limiting'
#
# Real output (claude-sonnet-5):
#   "Rate limiting is a technique for controlling how often actions or requests can
#    occur within a given time period, using algorithms like fixed window, sliding
#    window, token bucket, and leaky bucket to prevent overload, abuse, and ensure fair
#    resource access."
# Closeness: same core (cap requests per time window -> prevent overload/abuse, ensure
# fair use), and ~> adds the algorithms (token/leaky bucket, sliding window) in a deep
# technical register (high). 86% shorter -- 25 chars into a full definition.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

TARGET="Rate limiting is capping how many requests a user or client can make to a service in a given time window -- so no single caller can overwhelm the system, ensuring fair use and stability."
EXPR="~>'what is rate limiting'"

echo "TARGET (${#TARGET} chars): $TARGET"
echo "EXPR   (${#EXPR} chars): $EXPR"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
