#!/usr/bin/env bash
# nlir-golf · msm0 · #14 — "hierarchical summary" (map-reduce over a conversation)
#
# Genuinely MULTI-RECURSIVE: summarise the first half, summarise the second half,
# then summarise the JOIN of the two summaries — three summary calls, two feeding
# the third. The map-reduce technique for LONG threads that don't fit one context:
#
#   a=~0^*2 ; b=~3^*-1 ; ~( $a & $b )
#   │         │           └ ~($a & $b)  summarise the two half-summaries  (REDUCE)
#   │         └ b = ~3^*-1   summary of the SECOND half   (MAP)
#   └───────── a = ~0^*2     summary of the FIRST half    (MAP)
#
# The stack holds two intermediate summaries, then folds them into one — a summary
# of summaries. Scales past a single window by chunking, then merging.
#
# Real output (claude-sonnet-5) over a 6-turn search-architecture thread:
#   "The team will use tuned Postgres GIN/tsvector and trigram indexes (kept fresh
#    via a trigger or async worker) to achieve sub-second search over 10M documents
#    instead of adopting Elasticsearch."
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
 {"role":"user","content":"We need search across 10M documents with sub-second latency."},
 {"role":"assistant","content":"Use an inverted index; Elasticsearch or a tuned Postgres GIN index can both hit that."},
 {"role":"user","content":"We already run Postgres, so let's avoid a new system if we can."},
 {"role":"assistant","content":"Then GIN with tsvector, plus a trigram index for fuzzy matches, and materialized ranking."},
 {"role":"user","content":"How do we keep the index fresh as documents change?"},
 {"role":"assistant","content":"Update tsvector in a trigger or an async worker off the change feed to avoid write amplification."}
]}
JSON

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
say "a 6-turn search-architecture thread is in the context"
say 'HIERARCHICAL SUMMARY   a=~0^*2 ; b=~3^*-1 ; ~($a & $b)   — map each half, reduce the summaries'
printf '  => '
"$NLIR" --context-file "$CTX" --config "$CFG" --mode llm -e 'a=~0^*2;b=~3^*-1;~($a&$b)' --quiet
say "summary of summaries — the stack holds two intermediates, then folds them into one."
