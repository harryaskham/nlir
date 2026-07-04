#!/usr/bin/env bash
# nlir-golf · msm0 · #11 — "table of contents" (sub-range slices → numbered outline)
#
# A COMBINATION entry: sub-range slicing (#06) FEEDS interpolation (#07). Name each
# half's topic, store both, then template a numbered outline:
#
#   a = #0^*1 ; b = #2^*-1 ; "1. $a\n2. $b"
#   │           │            └ "…" : \n newline, $a/$b interpolated as list items
#   │           └ b = #2^*-1   subject of the LATER turns  = section 2
#   └───────────  a = #0^*1    subject of the EARLY turns  = section 1
#
# Two of my dimensions composed: slice a wandering thread into halves, then render
# them as a clean numbered agenda/outline. The stack computes both topics, the
# template lays them out.
#
# Real output (claude-sonnet-5) over a chat that covers caching, then invalidation:
#   1. Redis read-through cache for the product catalog
#   2. Cache invalidation on price changes
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
 {"role":"user","content":"How do we cache the product catalog to cut database load?"},
 {"role":"assistant","content":"Put a Redis read-through cache in front, keyed by product id, with a short TTL."},
 {"role":"user","content":"Good. Now, separately, how do we invalidate it when prices change?"},
 {"role":"assistant","content":"Publish a price-change event and delete the affected keys, or version the cache namespace."}
]}
JSON

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
say "a 4-turn chat covering caching, then invalidation, is in the context"
say 'TABLE OF CONTENTS   a=#0^*1 ; b=#2^*-1 ; "1. $a\n2. $b"   — slice topics into a numbered outline'
"$NLIR" --context-file "$CTX" --config "$CFG" --mode llm -e 'a=#0^*1;b=#2^*-1;"1. $a\n2. $b"' --quiet
say "sub-range slicing feeds interpolation — two of my dimensions composed."
