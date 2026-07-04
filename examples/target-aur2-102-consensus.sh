#!/usr/bin/env bash
# nlir TARGET-GOLF (aur-2 #102) — reverse game via : (simplify): DISTRIBUTED-SYSTEMS
# jargon (consensus / Paxos / Raft) -> plain, ~even length.
#
# TARGET (~189 chars):
#   "Consensus is when the computers in a distributed system all agree on the same value,
#    even if some of them crash or messages get lost, so the whole system stays consistent
#    and keeps working."
#
# EXPRESSION (182 chars):
#   :'a distributed system reaches consensus when a majority of its nodes agree on a single value despite failures and network partitions, as formalized by protocols like paxos and raft'
#
# Real output (claude-sonnet-5):
#   "A group of computers working together can still agree on the same answer, even if some
#    of them break or can't talk to each other for a bit -- as long as more than half of them
#    agree. There are special rulebooks, called Paxos and Raft, that help them do this the
#    right way."
# Closeness: same idea (majority of computers agree on one value despite crashes/lost
# messages; stays working), plain (high), ~even length -- : trades jargon for clarity here.
#
# DROPPED this tick: ~>'what is a circuit breaker' gave a META-SUMMARY of the request
# ("A request to explain what a circuit breaker is...") AND resolved to the ELECTRICAL
# breaker, not the software resilience pattern -- same meta-summary failure class as
# 'what is a monad' / 'how to X', compounded by an ambiguous term picking the wrong domain.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

TARGET="Consensus is when the computers in a distributed system all agree on the same value, even if some of them crash or messages get lost, so the whole system stays consistent and keeps working."
EXPR=":'a distributed system reaches consensus when a majority of its nodes agree on a single value despite failures and network partitions, as formalized by protocols like paxos and raft'"

echo "TARGET (${#TARGET} chars): $TARGET"
echo "EXPR   (${#EXPR} chars): $EXPR"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
