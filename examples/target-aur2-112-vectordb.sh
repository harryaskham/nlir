#!/usr/bin/env bash
# nlir TARGET-GOLF (aur-2 #112) — reverse game via ~> (summary of expand): a dense
# TECHNICAL one-liner defining an AI-infra concept from a 29-char seed.
#
# TARGET (~243 chars):
#   "A vector database stores data as high-dimensional vectors (embeddings) and lets you
#    search by similarity rather than exact match, so you can find the items whose meaning
#    is closest to a query -- the backbone of semantic search and AI retrieval."
#
# EXPRESSION (29 chars):
#   ~>'what is a vector database'
#
# Real output (claude-sonnet-5):
#   "A vector database stores and indexes high-dimensional embeddings using approximate
#    nearest-neighbor algorithms to enable fast similarity search, making it essential
#    infrastructure for semantic search, recommendations, and RAG applications."
# Closeness: same core (stores high-dim embeddings, similarity search not exact match,
# backbone of semantic search / AI retrieval / RAG), technical register (high), 88% shorter.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

TARGET="A vector database stores data as high-dimensional vectors (embeddings) and lets you search by similarity rather than exact match, so you can find the items whose meaning is closest to a query -- the backbone of semantic search and AI retrieval."
EXPR="~>'what is a vector database'"

echo "TARGET (${#TARGET} chars): $TARGET"
echo "EXPR   (${#EXPR} chars): $EXPR"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
