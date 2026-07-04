#!/usr/bin/env bash
# nlir-golf · aur1 · #38 — "the clarifier" (turn a vague ask into the right question back)
#
# The "let me make sure I understand" move. When the last user turn is vague, `~^_-1?`
# summarises it (abstracting to the underlying INTENT) and then questions THAT — so
# instead of parroting the ask, you get a confirm-the-intent question that surfaces
# what's MISSING. The ~ is doing the work: bare ^_-1? just re-punctuates the vague
# line; the summary first pulls out the intent, and ? asks it back.
#
#   CLARIFIER   ~ ^_-1 ?          (^_-1 = the last user turn)
#     ^_-1   "can you just make it faster"    (vague — faster how? which part?)
#     ^_-1?  "Can you just make it faster?"   (just adds a '?' — no help)
#     ~^_-1? "Does the user want a performance improvement — without further details?"
#             (names the intent AND flags the missing specifics = a real clarifier)
#
# This is the message-reads cousin of #30's focus-finder (which distils a long
# RAMBLE into one question). Here the input is a SHORT vague turn, and ~ supplies
# the "what you seem to be asking, is that right?" framing before ?. Practically:
# the first thing a good assistant does with an underspecified request.
#
# Run:  ./examples/golf-aur1-38-clarifier.sh
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
{"role":"user","content":"im building a dashboard that shows live order data"},
{"role":"assistant","content":"Nice — are you using websockets or polling for the live updates?"},
{"role":"user","content":"can you just make it faster"}
]}
JSON

say "CLARIFIER  ~^_-1?  — summarise the vague last user turn, then question it (confirm-the-intent)"
echo -n "  ^_-1   (raw vague ask) => "; "$NLIR" -e "^_-1"   --context-file "$CTX" --quiet
echo -n "  ^_-1?  (just punctuated)=> "; "$NLIR" -e "^_-1?"  --context-file "$CTX" --quiet
echo -n "  ~^_-1? (the clarifier) => "; "$NLIR" -e "~^_-1?" --context-file "$CTX" --quiet | fold -s -w 84 | sed '2,$s/^/       /'

say "~ pulls the intent out of a vague ask; ? asks it back. The message cousin of #30's focus-finder."
