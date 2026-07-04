#!/usr/bin/env bash
# nlir-golf · aur1 · #107 — "the triage train" (a LONG, reusable train run on REAL session context)
#
# Answering Harry's "I'm seeing the same short variations" — this is a genuinely LONG train that
# does a useful job on a REAL message, not a toy. Point four operators at the last user turn
# (^_-1) and get a four-level zoom on an incoming report — the readout an on-call engineer
# actually wants:
#
#   THE TRIAGE TRAIN   [ #^_-1 , ~^_-1 , @~^_-1 , >~^_-1 ]
#     #^_-1   ROUTE       — the topic tag, for routing / a channel name
#     ~^_-1   GIST        — the one-line summary
#     @~^_-1  FORMAL LINE — the sendable incident-channel / status sentence
#     >~^_-1  FULL BRIEF  — the fleshed-out situation for whoever picks it up
#
# Run on a REAL inbound ticket ("since the last deploy checkout throws a 500 for ~20% of users,
# PayPal specifically, started 2pm, 15 tickets, biggest revenue day, look asap"):
#     ROUTE       → "Checkout page 500 errors for PayPal payments"
#     GIST        → "Since the latest deploy, PayPal checkouts fail with 500s for ~20% of users
#                    on a peak revenue day — urgent."
#     FORMAL LINE → "Since the most recent deployment, ~20% of users (primarily PayPal) have
#                    encountered 500 errors during checkout…"
#     FULL BRIEF  → "Since the latest production deploy, ~20% of the user base hits HTTP 500 at
#                    checkout — transactions failing at the point of purchase rather than…"
#
# THE POINT (Harry's ask): this train is the same four sigils no matter WHAT lands in the inbox
# — it's REPEATABLE. Today I have to retype `[#^_-1, ~^_-1, @~^_-1, >~^_-1]` every time. The
# missing primitive is FUNCTION-binding: name it once — `triage := [#, ~, @~, >~]` — and then
# `triage ^_-1` on any message, `triage ↦ (0^-1)` to triage a whole thread. Trains are useful
# TODAY (this runs); naming them is the leap from a phrase you retype to a verb you reuse.
# (See examples/trains-aur2.md for static-text trains; this is the live-session-context one.)
#
# Run:  ./examples/golf-aur1-107-triagetrain.sh
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
{"role":"user","content":"hey, since the last deploy our checkout page has been throwing a 500 for about 20% of users, seems to be the ones paying with paypal specifically, started around 2pm, weve had like 15 support tickets already and its our biggest revenue day, can someone look asap"}
]}
JSON

say "THE TRIAGE TRAIN  [#^_-1, ~^_-1, @~^_-1, >~^_-1]  — a REUSABLE 4-level zoom on a REAL inbound ticket"
echo -n "  #^_-1   (ROUTE)       => "; "$NLIR" -e "#^_-1"   --context-file "$CTX" --quiet | fold -s -w 78 | sed '2,$s/^/       /'
echo -n "  ~^_-1   (GIST)        => "; "$NLIR" -e "~^_-1"   --context-file "$CTX" --quiet | fold -s -w 78 | sed '2,$s/^/       /'
echo -n "  @~^_-1  (FORMAL LINE) => "; "$NLIR" -e "@~^_-1"  --context-file "$CTX" --quiet | fold -s -w 78 | sed '2,$s/^/       /'
echo -n "  >~^_-1  (FULL BRIEF)  => "; "$NLIR" -e ">~^_-1"  --context-file "$CTX" --quiet | fold -s -w 78 | sed '2,$s/^/       /'

say "The SAME 4 sigils for ANY inbound message = REPEATABLE. The gap (Harry's lambda): name it once — triage := [#, ~, @~, >~] — then 'triage ^_-1' anywhere, 'triage ↦ (0^-1)' over a whole thread. Useful TODAY; naming is the leap from retyped phrase to reusable verb."
