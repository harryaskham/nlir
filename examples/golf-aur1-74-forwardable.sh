#!/usr/bin/env bash
# nlir-golf · aur1 · #74 — "the forwardable" (clean up your OWN last answer for sharing)
#
# The mirror of #62's escalation summary. There, `@~^_-1` took the USER's last turn — often
# a rant — and made it forwardable up the chain. Here, `@~^-1` reads the ASSISTANT's last
# turn — your own answer, thought-out-loud and casual — and makes it forwardable OUT: `~`
# keeps the findings, `@` lifts the register, and you get the clean version you'd paste into
# a team channel or a ticket.
#
#   THE FORWARDABLE   @ ~ ^-1        (^-1 = the last assistant turn)
#     raw   "yeah so i dug into it — the main culprit is were making 12 separate api calls
#            on page load, most sequential, and three hit the payments service having a rough
#            day latency-wise. quick win is parallelize the independent ones and cache the
#            shipping-rates call. that alone should cut load time roughly in half."
#     @~^-1 → "Page load performance is currently degraded by twelve largely sequential API
#             calls, three directed to an underperforming payments service. Executing
#             independent calls in parallel and caching the shipping-rates call is expected
#             to reduce load time by approximately half."
#
# Same tool, opposite end of the conversation: `@~^_-1` (#62) cleans up what THEY said to
# send UP; `@~^-1` cleans up what YOU said to send OUT. Register×length (#32) on a live
# message — one reads the question, the other reads the answer.
#
# Run:  ./examples/golf-aur1-74-forwardable.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT
cat > "$CTX" <<'JSON'
{"_messages":[
{"role":"user","content":"why is the checkout page so slow?"},
{"role":"assistant","content":"yeah so i dug into it — the main culprit is were making 12 separate api calls on page load, most of them sequential, and three of them hit the payments service which is having a rough day latency-wise. quick win is to parallelize the independent ones and cache the shipping-rates call which basically never changes. that alone should cut load time roughly in half."}
]}
JSON

say "THE FORWARDABLE  @~^-1  — the assistant's own last answer → a clean, formal, shareable summary"
echo -n "  ^-1   (raw answer)     => "; "$NLIR" -e "^-1"   --context-file "$CTX" --quiet | fold -s -w 82 | sed '2,$s/^/       /'
echo -n "  @~^-1 (the forwardable) => "; "$NLIR" -e "@~^-1" --context-file "$CTX" --quiet | fold -s -w 82 | sed '2,$s/^/       /'

say "Mirror of #62 escalation (@~^_-1 reads THEIR turn to send UP); this reads YOUR answer to send OUT. #32's plane on a live message."
