#!/usr/bin/env bash
# nlir-golf · aur1 · #79 — "the thread header" (title it by the opening ask, status it by the latest)
#
# A conversation has two anchor points: what it's ABOUT (fixed at the start) and where it's
# GOT TO (the latest turn). `[#^_0, ~^_-1]` reads both ends at once — `#^_0` names the thread
# from its opening user turn, `~^_-1` summarises the current state from the most recent user
# turn — giving you a header that spans origin → present.
#
#   THE THREAD HEADER   [ #^_0 , ~^_-1 ]
#     …a 3-turn thread about onboarding drop-off, now settling on magic-link…
#     #^_0  → "Onboarding funnel drop-off at the email verification step"          ← the TITLE
#     ~^_-1 → "The user wants to proceed with magic-link auth but needs a fallback for
#              users who can't access email on their phone."                       ← the STATE
#
# The title is stable — it's pinned to what the thread was ALWAYS about (`^_0`, the first user
# turn) — while the state moves with every message (`^_-1`, the last user turn). Distinct from
# my #54 triage (`[#^_-1, ~^_-1]`), which reads BOTH from the last message to route ONE
# incoming turn: this spans the WHOLE conversation — a stable heading over a live status,
# exactly the header you'd put on a support ticket or a resumed chat.
#
# Run:  ./examples/golf-aur1-79-header.sh
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
{"role":"user","content":"how do we stop our onboarding funnel from leaking users at the email verification step?"},
{"role":"assistant","content":"Most drop-off is on mobile; the verification email is slow and the link is hard to tap. Options: magic-link, shorter codes, or an SMS fallback."},
{"role":"user","content":"ok lets go with magic-link, but how do we handle users who dont have the email app on their phone?"}
]}
JSON

say "THE THREAD HEADER  [#^_0, ~^_-1]  — the TITLE (from the opening ask) + the STATE (from the latest turn)"
echo -n "  #^_0  (thread TITLE)  => "; "$NLIR" -e "#^_0"  --context-file "$CTX" --quiet | fold -s -w 82 | sed '2,$s/^/       /'
echo -n "  ~^_-1 (current STATE) => "; "$NLIR" -e "~^_-1" --context-file "$CTX" --quiet | fold -s -w 82 | sed '2,$s/^/       /'

say "Title pinned to ^_0 (stable, what it's ABOUT); state on ^_-1 (moves each turn). Spans origin→present — vs #54 triage (both on the last turn)."
