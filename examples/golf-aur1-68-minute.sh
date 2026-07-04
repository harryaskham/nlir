#!/usr/bin/env bash
# nlir-golf · aur1 · #68 — "the minute" (the latest exchange, distilled into one record line)
#
# A running decision log writes itself if you point `~` at the last back-and-forth.
# `~(^_-1 & ^-1)` joins the latest USER turn (`^_-1`, the question just asked) with the
# latest ASSISTANT turn (`^-1`, the answer just given) and summarises the pair into a
# single line — the minute you'd jot after that exchange.
#
#   THE MINUTE   ~ ( ^_-1 & ^-1 )
#     …conversation…
#       user  → "ok but what about burst traffic during a big launch?"      (^_-1)
#       asst  → "I'd suggest a token bucket per API key, backed by Redis…"   (^-1)
#     ~(^_-1 & ^-1) → "For burst traffic, use a Redis-backed token bucket per API key to
#                      keep rate limits persistent and consistent across instances."
#
# The `&` joins the question and the answer; the polymorphic `~` reads them as a Q→A pair
# and fuses them into the takeaway — not "here's a question and here's a reply" but the one
# line that records what was decided. Where my #33 arc and #45 loop-closer anchor on the
# FIRST turn (`^_0`) to capture the whole conversation's shape, this anchors on the PRESENT
# pair to capture the LATEST beat — a minute per exchange, not a summary of the whole.
#
# Run:  ./examples/golf-aur1-68-minute.sh
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
{"role":"user","content":"how should we handle rate limiting on the public api?"},
{"role":"assistant","content":"I'd suggest a token bucket per API key, backed by Redis for the counters, so limits survive restarts and scale across instances."},
{"role":"user","content":"ok but what about burst traffic during a big launch?"}
]}
JSON

say "THE MINUTE  ~(^_-1 & ^-1)  — the latest USER question + ASSISTANT answer, fused into one record line"
echo -n "  ^_-1  (last user)   => "; "$NLIR" -e "^_-1" --context-file "$CTX" --quiet | fold -s -w 82 | sed '2,$s/^/       /'
echo -n "  ^-1   (last asst)   => "; "$NLIR" -e "^-1"  --context-file "$CTX" --quiet | fold -s -w 82 | sed '2,$s/^/       /'
echo -n "  ~(^_-1 & ^-1) MINUTE => "; "$NLIR" -e "~(^_-1 & ^-1)" --context-file "$CTX" --quiet | fold -s -w 82 | sed '2,$s/^/       /'

say "& joins the Q and the A; ~ fuses them into the takeaway. Anchored on the PRESENT pair (vs #33/#45 on the first turn)."
