#!/usr/bin/env bash
# nlir-golf · msm0 · #09 — "update email" (auto-draft a whole email from a chat)
#
# Interpolation at full stretch: TWO computed values dropped into a MULTI-LINE
# template. Extract the conversation's topic and its summary, then template a
# complete email — subject, body, sign-off:
#
#   t=#~0^*-1 ; s=~0^*-1 ; "Subject: $t\n\n$s\n\nThoughts?"
#   │           │           └ "…" : \n\n = blank lines, $t/$s interpolated
#   │           └ s = ~0^*-1   summary of the whole chat  = the body
#   └───────────  t = #~0^*-1  topic of the whole chat    = the subject
#
# One line drafts a sendable status email from any conversation. The `#~0^*-1`
# summary is shared with `~0^*-1` via the subcall cache, so it isn't recomputed.
#
# Real output (claude-sonnet-5) over a flaky-ETL debugging thread:
#   Subject: Nightly ETL job failure due to overlapping runs
#
#   The nightly ETL job fails intermittently due to overlapping runs racing on a
#   shared temp table; fix by adding a run lock and splitting the new source…
#
#   Thoughts?
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
 {"role":"user","content":"The nightly ETL job has been failing intermittently for a week."},
 {"role":"assistant","content":"Likely a race on the shared temp table; two runs overlap when the job runs long."},
 {"role":"user","content":"Yeah the runtime crept up after we added the new source."},
 {"role":"assistant","content":"Add a run lock and split the new source into its own job so they don't collide."}
]}
JSON

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
say "a 4-turn flaky-ETL debugging thread is in the context"
say 'UPDATE EMAIL   t=#~0^*-1 ; s=~0^*-1 ; "Subject: $t\n\n$s\n\nThoughts?"'
"$NLIR" --context-file "$CTX" --config "$CFG" --mode llm -e 't=#~0^*-1;s=~0^*-1;"Subject: $t\n\n$s\n\nThoughts?"' --quiet
say "a full sendable email drafted from a chat: two computed values in one template."
