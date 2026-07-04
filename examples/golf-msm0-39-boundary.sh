#!/usr/bin/env bash
# nlir-golf · msm0 · #39 — "the collapse boundary" (where # STOPS collapsing info)
#
# I tried to make my #37 law pay off: if # collapses the information axis (#~x ≈ #x),
# then my #01 crux #~0^*-1 (2 LLM calls) should equal #0^*-1 (1 call) — free speedup.
# It DOESN'T. On a conversation they DIFFER, and the difference is the finding:
#
#   #0^*-1   => "Webhook delivery reliability"                        <- the PROBLEM topic
#   #~0^*-1  => "Webhook delivery retry logic with dead-letter queue" <- the SOLUTION topic
#
# WHY the collapse breaks: #37's #~x ≈ #x holds for a FOCUSED text (one dominant
# topic). But a conversation carries a PROBLEM and a SOLUTION. ~ (summary) RE-WEIGHTS
# emphasis toward the resolution, and # is EMPHASIS-sensitive (#28) — so it follows
# the shift. The information-axis collapse holds only while ~ doesn't redistribute
# emphasis across PARTS; a multi-part text is exactly where it fails.
#
# So the ~ in crux is NOT redundant — #0^*-1 and #~0^*-1 are TWO useful lenses:
#   #0^*-1  = what the conversation is ABOUT (the problem)
#   #~0^*-1 = what it RESOLVED TO (the solution)
# Mapping a law's BOUNDARY is as useful as the law: it turned a "redundant" op into a
# second lens.
#
# Real output (claude-sonnet-5) over a webhook-reliability thread — see above.
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
 {"role":"user","content":"Our webhook deliveries are unreliable — some events never reach the customer endpoint."},
 {"role":"assistant","content":"Add retries with exponential backoff and a dead-letter queue for events that exhaust retries."},
 {"role":"user","content":"And how do we prove delivery to customers who dispute it?"},
 {"role":"assistant","content":"Log each attempt with a delivery id and expose a delivery-status endpoint they can query."}
]}
JSON

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
say "a 4-turn webhook-reliability thread (a PROBLEM + a SOLUTION) is in the context"
say '#0^*-1 (raw topic = PROBLEM) vs #~0^*-1 (summary topic = SOLUTION) — the collapse #37 BREAKS here'
printf '  #0^*-1   => '; "$NLIR" --context-file "$CTX" --config "$CFG" --mode llm -e '#0^*-1' --quiet
printf '  #~0^*-1  => '; "$NLIR" --context-file "$CTX" --config "$CFG" --mode llm -e '#~0^*-1' --quiet
say "~ re-weights emphasis problem->solution; # (emphasis-sensitive, #28) follows. Two lenses, not a redundancy."
