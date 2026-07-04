#!/usr/bin/env bash
# nlir-golf · msm0 · #12 — "status card" (resume a conversation at a glance)
#
# A COMBINATION of two reads at DIFFERENT scopes, composed via interpolation.
# The whole-chat topic (crux) plus the currently-open question (the latest user
# turn), on one line:
#
#   t=#~0^*-1 ; o=~^_-1 ; "Topic: $t | Open: $o"
#   │           │          └ "…" : interpolate both into a status line
#   │           └ o = ~^_-1   summary of the LATEST user turn  = what's open now
#   └───────────  t = #~0^*-1  subject of the whole chat       = the topic
#
# One reads the whole thread (wide scope), the other just the last ask (narrow) —
# together a "where are we / what's next" card for context-switching back in.
#
# Real output (claude-sonnet-5) over a notifications-design thread:
#   Topic: Notifications service | Open: The system needs a fallback mechanism to
#   prevent an unreliable email provider from delaying or blocking push delivery.
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
 {"role":"user","content":"We're designing the notifications service. Push, email, or both?"},
 {"role":"assistant","content":"Both, behind a user preference; fan out from one event bus so channels stay decoupled."},
 {"role":"user","content":"How do we stop a flaky email provider from blocking push delivery?"}
]}
JSON

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
say "a 3-turn notifications-design thread is in the context"
say 'STATUS CARD   t=#~0^*-1 ; o=~^_-1 ; "Topic: $t | Open: $o"   — topic + current open question'
printf '  => '
"$NLIR" --context-file "$CTX" --config "$CFG" --mode llm -e 't=#~0^*-1;o=~^_-1;"Topic: $t | Open: $o"' --quiet
say "wide-scope topic + narrow-scope latest ask, composed — a resume-the-thread card."
