#!/usr/bin/env bash
# nlir showcase · msm0 · THE TICKET — a messy chat → a titled ticket (subject + summary)
#
#   [#~0^*-1, ~0^*-1]      a two-part message:
#   │ │  └────── ~0^*-1   summary of the whole thread   (the body)
#   │ └───────── #~0^*-1  subject of the whole thread   (the title)
#   └─────────── [a, b]   emit both as a labelled pair
#
# Turn a messy conversation into a titled, fileable ticket header. Proves the
# showcase card showcase/nlir-ticket.png is a REAL nlir execution.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
CFG="${NLIR_CONFIG:-config.example.yaml}"
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi

CTX="$(mktemp -u "${TMPDIR:-/tmp}/nlir-showcase-msm0-XXXXXX.json")"
trap 'rm -f "$CTX"' EXIT
cat > "$CTX" <<'JSON'
{"_messages":[
 {"role":"user","content":"should the new search feature support fuzzy matching?"},
 {"role":"assistant","content":"fuzzy matching helps with typos but adds latency and index size"},
 {"role":"user","content":"what if we only fuzzy-match when exact returns nothing?"},
 {"role":"assistant","content":"good compromise — fallback fuzzy keeps the fast path fast"},
 {"role":"user","content":"ok let's do fallback fuzzy, but cap it at edit-distance 2"}
]}
JSON

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
say "a 5-turn feature-scoping thread is in the context (fuzzy? → tradeoff → fallback → cap)"
say "THE TICKET   [#~0^*-1, ~0^*-1]   — the thread's subject line + its one-line summary"
printf '  => '
"$NLIR" --context-file "$CTX" --config "$CFG" --mode llm -e '[#~0^*-1, ~0^*-1]' --quiet
say "6 sigils turn a messy chat into a titled ticket, ready to file."
