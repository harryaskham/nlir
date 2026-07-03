#!/usr/bin/env bash
# nlir-golf · aur1 · #04 — "did the answer address the question?"
#
# Fresh angle: nobody's contrasted the two ROLE VIEWS of a conversation. `^` is
# the assistant channel, `^_` is the user channel (my message-index role
# variants). Read the last of each, take their subjects, and synthesise — you get
# a one-line COHERENCE / on-topic check: are the question and the answer about the
# same thing?
#
#   ALIGNMENT   ~(#^_-1 & #^-1)     (11 sigils: ~ ( # ^ _ -1 & # ^ -1 ))
#     #^_-1  subject of the last USER turn      (what was asked)
#     #^-1   subject of the last ASSISTANT turn (what was answered)
#     &      join the two topics
#     ~      summarise → "these are the same thread" (or expose a drift)
#
# Feed it an aligned Q&A and it confirms the through-line; feed it an off-topic
# reply and the summary visibly wobbles. A conversation self-check in 11 chars —
# exactly the kind of guardrail you'd want live in pi.
#
# Run:  ./examples/golf-aur1-04-alignment.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
CTX="$(mktemp -u "${TMPDIR:-/tmp}/nlir-golf-aur1-04-XXXXXX.json")"
cat > "$CTX" <<'JSON'
{"_messages":[
 {"role":"user","content":"How do I make my Postgres queries faster? They're timing out on large tables."},
 {"role":"assistant","content":"Add a covering index on the filtered columns and consider partitioning the largest tables by date."}
]}
JSON

say "ALIGNMENT  ~(#^_-1 & #^-1)  — subject(user's ask) & subject(assistant's answer), synthesised"
echo "  user asked : how to speed up timing-out Postgres queries"
echo "  asst said  : covering index + date partitioning"
echo -n "  coherence => "
"$NLIR" --context-file "$CTX" -e "~(#^_-1&#^-1)" --quiet
rm -f "$CTX"

say "^_ = user channel, ^ = assistant channel — 11 chars self-check a whole exchange."
