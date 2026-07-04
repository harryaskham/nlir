#!/usr/bin/env bash
# nlir-golf · msm0 · #16 — "catch-up" (condensed background + the latest, verbatim)
#
# Two RANGE tricks in one card: the EXCLUDE-LAST range `0^*-2` (every turn BEFORE
# the last) summarised as background, and `^*-1` — the last turn across ALL roles,
# read verbatim:
#
#   p=~0^*-2 ; n=^*-1 ; "Context: $p\nLatest: $n"
#   │          │         └ "…" : background condensed, latest exact
#   │          └ n = ^*-1     the LATEST turn, any role, verbatim  (NOT ^-1 = last assistant)
#   └───────── p = ~0^*-2     summary of everything EXCEPT the last turn = the background
#
# The teaching bit: `^-1` is the last ASSISTANT turn; `^*-1` is the last turn of
# ANY role — here the user's newest question. Background gets condensed (you only
# need the gist); the latest stays exact (you need it word-for-word). A "resume
# here" card for hopping back into a thread.
#
# Real output (claude-sonnet-5) over a message-queue selection thread:
#   Context: Given the high throughput (~50k msgs/sec) and need for replay after
#            outages, Kafka is the better choice over RabbitMQ.
#   Latest:  Ok Kafka it is. How many partitions should we start with?
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
 {"role":"user","content":"We're picking a message queue for the order pipeline."},
 {"role":"assistant","content":"Kafka for high throughput and replay; RabbitMQ if you need per-message routing and simpler ops."},
 {"role":"user","content":"We need replay after outages and we do ~50k msgs/sec."},
 {"role":"assistant","content":"That points to Kafka: partitioned topics, consumer groups, and retention for replay."},
 {"role":"user","content":"Ok Kafka it is. How many partitions should we start with?"}
]}
JSON

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
say "a 5-turn message-queue selection thread is in the context"
say 'CATCH-UP   p=~0^*-2 ; n=^*-1 ; "Context: $p\nLatest: $n"   — background summary + latest verbatim'
"$NLIR" --context-file "$CTX" --config "$CFG" --mode llm -e 'p=~0^*-2;n=^*-1;"Context: $p\nLatest: $n"' --quiet
say "exclude-last range 0^*-2 condenses the background; ^*-1 keeps the newest turn exact."
