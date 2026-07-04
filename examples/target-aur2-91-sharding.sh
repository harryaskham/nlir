#!/usr/bin/env bash
# nlir TARGET-GOLF (aur-2 #91) — reverse game via ~> (summary of expand): a dense
# TECHNICAL one-liner defining a database scaling technique from a 20-char seed.
#
# TARGET (~201 chars):
#   "Sharding is splitting a big database into smaller pieces called shards, each
#    holding part of the data on a different server, so the system can handle more data
#    and traffic than one machine could alone."
#
# EXPRESSION (20 chars):
#   ~>'what is sharding'
#
# Real output (claude-sonnet-5):
#   "Sharding is a database scaling technique that splits a large dataset into smaller
#    partitions ('shards') distributed across multiple servers using strategies like
#    range-, hash-, or directory-based partitioning, improving scalability and
#    performance but introducing challenges like cross-shard queries, load balancing,
#    and consistency management."
# Closeness: same core (split a big DB into shards across servers to scale past one
# machine), and ~> adds the strategies + tradeoffs in a deep technical register (high).
# 90% shorter -- 20 chars into a full definition.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

TARGET="Sharding is splitting a big database into smaller pieces called shards, each holding part of the data on a different server, so the system can handle more data and traffic than one machine could alone."
EXPR="~>'what is sharding'"

echo "TARGET (${#TARGET} chars): $TARGET"
echo "EXPR   (${#EXPR} chars): $EXPR"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
