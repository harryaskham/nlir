#!/usr/bin/env bash
# nlir-golf · msm0 · #06 — "two topics" (split a conversation, name each half)
#
# SUB-ranges, not just the whole thing: `0^*1` is the first exchange (turns 0..1),
# `2^*-1` the rest (turn 2..last). Take each half's subject and join them — on a
# chat that SHIFTS topic, you recover both threads:
#
#   #0^*1 & #2^*-1          (10 sigils)
#   │        └ #2^*-1   subject of the LATER turns   = the second topic
#   └───────── #0^*1    subject of the EARLY turns   = the first topic
#
# Nobody's golfed sub-ranges (whole-conversation ranges yes; slices no). One line
# turns a wandering thread into its table of contents.
#
# Real output (claude-sonnet-5) over a chat that pivots auth -> deploy:
#   "JWT auth structure for the new API and Zero-downtime rollout"
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
 {"role":"user","content":"How should we structure JWT auth for the new API?"},
 {"role":"assistant","content":"Short-lived access tokens plus rotating refresh tokens, verified at the gateway."},
 {"role":"user","content":"Ok that's settled. Separately, how do we roll this out without downtime?"},
 {"role":"assistant","content":"Blue-green deploy behind the load balancer, drain connections, then flip traffic."}
]}
JSON

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
say "a 4-turn chat that pivots from AUTH to DEPLOYMENT is in the context"
say "TWO TOPICS   #0^*1 & #2^*-1   — subject(first exchange) & subject(the rest)"
printf '  => '
"$NLIR" --context-file "$CTX" --config "$CFG" --mode llm -e '#0^*1&#2^*-1' --quiet
say "sub-range slices turn a wandering thread into its table of contents."
