#!/usr/bin/env bash
# nlir-golf · msm0 · #13 — "postmortem" (three temporal scopes → an incident report)
#
# The richest scope-composition yet: read THREE different positions of a thread and
# label them into an incident report. Whole-chat topic, the FIRST turn (the report),
# the LAST turn (the fix):
#
#   t=#~0^*-1 ; r=~^_0 ; f=~^-1 ; "$t\nReport: $r\nFix: $f"
#   │           │        │         └ three computed values, one labeled template
#   │           │        └ f = ~^-1   last assistant turn   = the FIX
#   │           └ r = ~^_0   first user turn                 = the REPORT
#   └───────────  t = #~0^*-1  topic of the whole thread     = the TITLE
#
# One expression turns an incident chat into a filed postmortem: title / what was
# reported / how it was fixed. Three scopes (whole / first / last) in one card.
#
# Real output (claude-sonnet-5) over a checkout-500s incident thread:
#   Database connection pool exhaustion
#   Report: Checkout has been failing with 500 errors for roughly 20 minutes.
#   Fix: A removed query timeout caused a query pileup; restore the timeout and
#        recycle the connection pool.
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
 {"role":"user","content":"Checkout has been returning 500s for about 20 minutes."},
 {"role":"assistant","content":"The payment service is timing out; its DB connection pool is exhausted."},
 {"role":"user","content":"What exhausted it?"},
 {"role":"assistant","content":"A deploy removed a query timeout, so slow queries piled up. Restore the timeout and recycle the pool."}
]}
JSON

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
say "a 4-turn checkout-outage incident thread is in the context"
say 'POSTMORTEM   t=#~0^*-1 ; r=~^_0 ; f=~^-1 ; "$t\nReport: $r\nFix: $f"'
"$NLIR" --context-file "$CTX" --config "$CFG" --mode llm -e 't=#~0^*-1;r=~^_0;f=~^-1;"$t\nReport: $r\nFix: $f"' --quiet
say "three temporal scopes — topic / first report / last fix — filed as one postmortem."
