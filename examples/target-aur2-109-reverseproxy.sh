#!/usr/bin/env bash
# nlir TARGET-GOLF (aur-2 #109) — reverse game via ~> (summary of expand): a dense
# TECHNICAL one-liner defining a networking concept from a 27-char seed.
#
# TARGET (~249 chars):
#   "A reverse proxy is a server that sits in front of your web servers and takes all
#    incoming requests first, then forwards them to the right backend -- handling things
#    like load balancing, caching, and SSL so clients never talk to your servers directly."
#
# EXPRESSION (27 chars):
#   ~>'what is a reverse proxy'
#
# Real output (claude-sonnet-5):
#   "A reverse proxy is a server that sits in front of backend web servers, intercepting and
#    routing client requests to them while providing benefits like load balancing, SSL
#    termination, caching, security, and backend server anonymity."
# Closeness: same core (server in front of backends, routes client requests, load
# balancing/caching/SSL, clients don't hit servers directly), technical (high), 89% shorter.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

TARGET="A reverse proxy is a server that sits in front of your web servers and takes all incoming requests first, then forwards them to the right backend -- handling things like load balancing, caching, and SSL so clients never talk to your servers directly."
EXPR="~>'what is a reverse proxy'"

echo "TARGET (${#TARGET} chars): $TARGET"
echo "EXPR   (${#EXPR} chars): $EXPR"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
