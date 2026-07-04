#!/usr/bin/env bash
# nlir-golf · msm0 · #21 — "FAQ synthesis" (opening question, whole-thread answer)
#
# Turn a multi-turn thread into ONE knowledge-base entry: read the OPENING question
# verbatim, answer it with a summary of the ENTIRE conversation:
#
#   q=^_0 ; a=~0^*-1 ; "Q: $q\nA: $a"
#   │       │           └ "…" : Q + A card
#   │       └ a = ~0^*-1   summary of the WHOLE thread   = the complete answer
#   └────── q = ^_0        the first user turn, verbatim  = the question
#
# Distinct from #08 flashcard (a single exchange): here the answer condenses
# EVERYTHING the discussion established, so late detail folds back into the opening
# question. Two boundaries mapped getting here (honest notes):
#   • #~0^*-1? (questionify the topic) DEGENERATES — ? needs a verb+object; a bare
#     noun-phrase topic ("TCP and UDP") won't questionify. So read the real opening
#     question verbatim (^_0) instead.
#   • bookends q=^_0;a=~^-1 MISMATCH in multi-topic threads — the last answer
#     addresses the latest turn, not the opening question. So synthesise the WHOLE
#     thread (~0^*-1), not just ~^-1.
#
# Real output (claude-sonnet-5) over a TCP/UDP thread that drifts into "when UDP":
#   Q: What's the difference between TCP and UDP?
#   A: TCP offers reliable, ordered delivery while UDP is faster but connectionless,
#      making UDP the choice when low latency matters more than guaranteed delivery.
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
 {"role":"user","content":"What's the difference between TCP and UDP?"},
 {"role":"assistant","content":"TCP is connection-oriented and reliable with ordering and retransmission; UDP is connectionless, unordered, and fast with no delivery guarantee."},
 {"role":"user","content":"So when would I pick UDP?"},
 {"role":"assistant","content":"When low latency beats reliability — live video, games, DNS, telemetry — and you can tolerate or handle loss yourself."}
]}
JSON

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
say "a 4-turn TCP/UDP thread (that drifts into 'when to pick UDP') is in the context"
say 'FAQ SYNTHESIS   q=^_0 ; a=~0^*-1 ; "Q: $q\nA: $a"   — opening question, whole-thread answer'
"$NLIR" --context-file "$CTX" --config "$CFG" --mode llm -e 'q=^_0;a=~0^*-1;"Q: $q\nA: $a"' --quiet
say "the opening question answered by the entire discussion — a knowledge-base entry from a thread."
