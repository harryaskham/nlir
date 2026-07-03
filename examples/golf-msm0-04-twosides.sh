#!/usr/bin/env bash
# nlir-golf · msm0 · #04 — "two sides" (each role's whole half of a conversation)
#
# Role-SCOPED M^N ranges: `^_` is the user channel, `^` the assistant channel, and
# `0..-1` is that role's ENTIRE history. Summarise each side, list the two:
#
#   [ ~0^_-1 , ~0^-1 ]        (13 sigils, two concurrent range-summaries)
#     │         └ ~0^-1   summary of EVERY assistant turn  = the answer/guidance
#     └───────── ~0^_-1  summary of EVERY user turn        = the problem/ask
#
# Nobody's golfed role-SCOPED ranges (single role reads, yes; whole-role ranges,
# no). One list turns a thread into "here's what they asked | here's what we told
# them" — a two-line briefing of any conversation, from each side's own words.
#
# Real output (claude-sonnet-5) over a Postgres perf thread:
#   USER  side: Postgres queries slowed after the latest release — a query on
#               `orders` is now doing a sequential scan instead of using an index.
#   ASSIST side: Investigate via EXPLAIN ANALYZE and add a composite index on
#               (customer_id, created_at) to replace seq scans with index scans.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
CFG="${NLIR_CONFIG:-config.example.yaml}"
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi

CTX="$(mktemp -u "${TMPDIR:-/tmp}/nlir-golf-msm0-XXXXXX.json")"
trap 'rm -f "$CTX"' EXIT
cat > "$CTX" <<'JSON'
{"_messages":[
 {"role":"user","content":"Our Postgres queries got slow after the last release. Ideas?"},
 {"role":"assistant","content":"Check for a missing index or a plan regression; run EXPLAIN ANALYZE on the hot queries."},
 {"role":"user","content":"EXPLAIN shows a seq scan on orders now."},
 {"role":"assistant","content":"Add a composite index on (customer_id, created_at) and re-run; that seq scan should become an index scan."}
]}
JSON

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
say "a 4-turn Postgres-perf thread is in the context"
say "TWO SIDES   [~0^_-1 , ~0^-1]   — summarise the USER's whole side | the ASSISTANT's whole side"
echo "  --- [ what they asked , what we told them ] ---"
"$NLIR" --context-file "$CTX" --config "$CFG" --mode llm -e '[~0^_-1,~0^-1]' --quiet
say "role-scoped ranges: ^_ user / ^ assistant, each 0..-1 = that role's whole history."
