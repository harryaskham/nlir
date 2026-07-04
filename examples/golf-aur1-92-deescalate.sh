#!/usr/bin/env bash
# nlir-golf · aur1 · #92 — "the de-escalator" (@^_-1 : rewrite an angry draft calm, keeping every point)
#
# The message you WANT to send when you're furious, made sendable. `@^_-1` reads the user's
# last turn — a hot draft — and lifts it to a calm, professional register with `@`, but WITHOUT
# `~`, so it keeps every point at full length. Not a summary for someone else — the same
# message, re-voiced, ready to actually send.
#
#   THE DE-ESCALATOR   @ ^_-1        (^_-1 = the last user turn)
#     raw   "honestly this is ridiculous. you promised the api docs would be done last week
#            and theres STILL nothing, and now MY team is blocked and looking bad because of
#            YOUR delay. this keeps happening and im sick of it. get it done today."
#     @^_-1 → "I understand the API documentation was committed for delivery last week and has
#             not yet been completed. As a result, my team is now blocked and this is affecting
#             our credibility. Additionally, this is not the first time such delays have
#             occurred, and the recurring pattern is a significant concern. I would appreciate
#             it if this could be completed today."
#
# Every point survives — the missed deadline, the block, the credibility hit, the recurrence,
# the ask for today — but "ridiculous", "STILL", "YOUR delay", "sick of it" are gone. That's
# the `@`-ALONE move: it shifts REGISTER without touching LENGTH. Contrast my #62 escalation
# (`@~^_-1`): the `~` there SUMMARISES the rant into a short report to send UP the chain; this
# KEEPS the whole message to send ACROSS, just in a voice you won't regret.
#
# Run:  ./examples/golf-aur1-92-deescalate.sh
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
{"role":"user","content":"honestly this is ridiculous. you promised the api docs would be done last week and theres STILL nothing, and now MY team is blocked and looking bad because of YOUR delay. this keeps happening and im sick of it. get it done today."}
]}
JSON

say "THE DE-ESCALATOR  @^_-1  — rewrite the user's heated draft in a calm register, KEEPING every point"
echo -n "  ^_-1  (raw angry draft)  => "; "$NLIR" -e "^_-1"  --context-file "$CTX" --quiet | fold -s -w 82 | sed '2,$s/^/       /'
echo -n "  @^_-1 (the calm version) => "; "$NLIR" -e "@^_-1" --context-file "$CTX" --quiet | fold -s -w 82 | sed '2,$s/^/       /'

say "@ alone shifts REGISTER without touching LENGTH — every point kept, the heat removed. vs #62 escalation @~^_-1 (the ~ SUMMARISES to send up); this KEEPS it all to send across."
