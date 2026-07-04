#!/usr/bin/env bash
# nlir-golf · msm0 · #17 — "follow-up" (interpolation on the INPUT side of an op)
#
# Every prior interpolation entry fed a value into OUTPUT text. This one feeds a
# computed value into the OPERAND of an LLM op — prompt construction. Extract the
# topic, splice it into a request, and formalise that constructed request:
#
#   t=#~0^*-1 ; @"following up — any progress on $t?"
#   │           └ @( "following up — any progress on <topic>?" )  formalise the
#   │             INTERPOLATED prompt into a finished message
#   └────────── t = #~0^*-1   topic of the whole thread, spliced into the prompt
#
# So the LLM never sees `$t` — it sees the topic already woven into the request,
# then lifts it to a polished follow-up. Interpolation as PROMPT TEMPLATING, not
# just output templating — nlir writing its own next prompt from the conversation.
#
# Real output (claude-sonnet-5) over a JWT-migration scoping thread:
#   "I am writing to inquire about the current status of the migration from sessions
#    to JWT. Could you please provide an update on the progress made thus far?"
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
 {"role":"user","content":"Can you scope the work to migrate our auth from sessions to JWT?"},
 {"role":"assistant","content":"Three phases: issue JWTs alongside sessions, migrate clients, then retire sessions."},
 {"role":"user","content":"Good. Let's start phase one next sprint."}
]}
JSON

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
say "a 3-turn JWT-migration scoping thread is in the context"
say 'FOLLOW-UP   t=#~0^*-1 ; @"following up — any progress on $t?"   — splice the topic INTO a prompt'
printf '  => '
"$NLIR" --context-file "$CTX" --config "$CFG" --mode llm -e 't=#~0^*-1;@"following up — any progress on $t?"' --quiet
say "interpolation as PROMPT templating — nlir writes its own next message from the thread."
