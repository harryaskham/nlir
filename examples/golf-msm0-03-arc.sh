#!/usr/bin/env bash
# nlir-golf · msm0 · #03 — "the arc" (a conversation's journey in one line)
#
# Read the TWO ENDS of a conversation and fuse them: the first thing the USER
# asked (^_0 = user channel, index 0) and the last thing the ASSISTANT said
# (^-1 = assistant channel), joined and summarised:
#
#   ~ ( ^_0 & ^-1 )         (8 sigils)
#   │   │     └ ^-1   last ASSISTANT turn  (the resolution)
#   │   └────── ^_0   first USER turn      (the original ask)  — ^_ = user role view
#   └────────── ~(… & …)  summarise the opening ask + the final answer = the ARC
#
# Distinct from a coherence check (aur-1's #^_-1 & #^-1, last-vs-last): this reads
# the temporal ENDS — first ask → final answer — to yield the takeaway. Uses BOTH
# role channels (^_ user / ^ assistant) at indexed positions.
#
# Real output (claude-sonnet-5) over an API-timeout debugging thread:
#   "To stop your API from timing out under load, raise the connection pool
#    ceiling, add a backpressure-aware queue, and cache hot reads."
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
 {"role":"user","content":"How do I stop my API from timing out under load?"},
 {"role":"assistant","content":"Profile first; usually it's DB connection pool exhaustion or a slow N+1 query."},
 {"role":"user","content":"It's the connection pool — we max out at 20."},
 {"role":"assistant","content":"Raise the pool ceiling, add a queue with backpressure, and cache hot reads."}
]}
JSON

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
say "a 4-turn API-timeout debugging thread is in the context"
say "THE ARC   ~(^_0 & ^-1)   — summarise the first USER ask + the last ASSISTANT answer"
printf '  => '
"$NLIR" --context-file "$CTX" --config "$CFG" --mode llm -e '~(^_0&^-1)' --quiet
say "8 sigils fuse the two ends of a conversation into its actionable takeaway."
