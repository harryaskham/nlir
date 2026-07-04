#!/usr/bin/env bash
# nlir-golf · msm0 · #52 — "auto-ack" (acknowledge the pending question, specifically)
#
# When someone's waiting on you, a generic "on it!" is worse than one that names what
# you're on. This surfaces the PENDING user question and generates a specific ack:
#
#   q=~^_-1 ; @"quick note — im on $q and will follow up shortly"
#   │         └ @( "…$q…" )   formalise the acknowledgment (input-interp, #17)
#   └──────── q = ~^_-1   the LAST user turn, summarised = the open loop / pending ask
#
# So the reply references the exact thing you're handling, not a boilerplate ack —
# input-side interpolation aimed at the open loop. (Reads ^_-1: the last USER turn, the
# one awaiting a response.)
#
# Real output (claude-sonnet-5) over a staging-deploy thread ending on "check the
# rollback script works before we retry":
#   "Please note that I am currently reviewing the request for the rollback script to be
#    tested and confirmed as functioning correctly prior to the next attempt. I will
#    follow up shortly with further details."
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
CFG="${NLIR_CONFIG:-config.example.yaml}"
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi

CTX="$(mktemp "${TMPDIR:-/tmp}/nlir-golf-msm0-XXXXXX.json")"
trap 'rm -f "$CTX"' EXIT
cat > "$CTX" <<'JSON'
{"_messages":[
 {"role":"user","content":"The staging deploy is failing on the migration step."},
 {"role":"assistant","content":"Likely a locked table; check for a long-running query holding the lock."},
 {"role":"user","content":"Can you also check whether the rollback script actually works before we try again?"}
]}
JSON

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
say "a thread ending on a pending user ask (check the rollback script) is in the context"
say 'AUTO-ACK   q=~^_-1 ; @"quick note — im on $q and will follow up shortly"'
printf '  => '
"$NLIR" --context-file "$CTX" --config "$CFG" --mode llm -e 'q=~^_-1;@"quick note — im on $q and will follow up shortly"' --quiet
say "the pending question spliced into the ack — a reply that names what you're on, not boilerplate."
