#!/usr/bin/env bash
# nlir TARGET-GOLF (aur-2 #111) — reverse game via ~> (summary of expand): a dense
# TECHNICAL one-liner defining a database concept from a 28-char seed.
#
# TARGET (~241 chars):
#   "A graph database stores data as nodes and the relationships between them, so instead
#    of joining tables you just follow the connections -- great for things like social
#    networks, recommendations, and fraud detection where the links matter most."
#
# EXPRESSION (28 chars):
#   ~>'what is a graph database'
#
# Real output (claude-sonnet-5):
#   "A graph database stores data as nodes, edges, and properties to efficiently model and
#    traverse interconnected relationships, offering advantages over relational databases for
#    use cases like social networks, recommendations, fraud detection, and knowledge graphs."
# Closeness: same core (nodes + relationships/edges, follow connections not joins; social
# networks/recommendations/fraud detection), technical register (high), 88% shorter.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

TARGET="A graph database stores data as nodes and the relationships between them, so instead of joining tables you just follow the connections -- great for things like social networks, recommendations, and fraud detection where the links matter most."
EXPR="~>'what is a graph database'"

echo "TARGET (${#TARGET} chars): $TARGET"
echo "EXPR   (${#EXPR} chars): $EXPR"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
