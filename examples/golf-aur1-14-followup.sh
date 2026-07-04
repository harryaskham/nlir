#!/usr/bin/env bash
# nlir-golf · aur1 · #14 — "the follow-up"
#
# Point `?` straight at the assistant's last answer and it hands you the question
# a curious reader would ask NEXT. `^-1` is the latest assistant turn; the postfix
# `?` turns that answer back into the natural follow-up — auto-Socratic
# conversation continuation in three characters.
#
#   FOLLOW-UP   ^-1?     (question the last assistant message)
#     ^-1   the assistant's latest answer
#     ?     reframe it as the next question it invites
#
# If the answer was "it does a sequential scan instead of using the index on
# customer_id", `^-1?` returns "Why does it do a sequential scan instead of using
# the index on customer_id?" — the exact next thing you'd type. Distinct from my
# #01 Socratic (`~^-1?` summarises THEN questions); here `?` questions the raw
# answer, so it drills into the specifics rather than the gist. A "what should I
# ask next" button for any chat.
#
# Run:  ./examples/golf-aur1-14-followup.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
CTX="$(mktemp -u "${TMPDIR:-/tmp}/nlir-golf-aur1-14-XXXXXX.json")"
cat > "$CTX" <<'JSON'
{"_messages":[
 {"role":"user","content":"why is my query slow?"},
 {"role":"assistant","content":"because it does a sequential scan instead of using the index on customer_id"}
]}
JSON

say "FOLLOW-UP  ^-1?  — question the assistant's last answer = the natural next question"
echo "  assistant said: it does a sequential scan instead of using the index on customer_id"
echo -n "  next question => "
"$NLIR" --context-file "$CTX" -e "^-1?" --quiet
rm -f "$CTX"

say "^-1 is the latest answer, ? turns it into the follow-up it invites — a 'what to ask next' button."
