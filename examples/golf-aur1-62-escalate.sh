#!/usr/bin/env bash
# nlir-golf · aur1 · #62 — "the escalation summary" (a heated message → a clean forward)
#
# The compose-yourself button. `@~^_-1` reads the user's last turn — often a frustrated
# rant — and hands you a clean, forwardable version: `~` condenses it to the facts, `@`
# strips the heat and lifts it to a professional register. Perfect for escalating a Slack
# vent up the chain without the venting: the substance survives, the emotion is filed as
# "the author has expressed frustration."
#
#   ESCALATION SUMMARY   @ ~ ^_-1        (^_-1 = the last user turn)
#     raw   "this is the THIRD time the deploy broke prod this week and honestly im losing
#            my mind, we keep saying well fix the pipeline but nothing changes and now
#            customers are complaining, someone needs to actually own this"
#     @~^_-1 → "Recurring deployment failures have continued to disrupt production this
#              week, with no resolution yet implemented. The author has expressed
#              frustration and indicated that clear ownership of the pipeline must be
#              established."
#
# `~` keeps the three facts (repeat incidents, no fix, customer impact) and the ask
# (ownership); `@` converts "losing my mind" into a calm, escalatable note. It's the
# register×length plane (my #32) aimed at a live MESSAGE — the professional translation of
# a heated one, ready to paste into the incident channel.
#
# Run:  ./examples/golf-aur1-62-escalate.sh
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
{"role":"user","content":"this is the THIRD time the deploy has broken prod this week and honestly im losing my mind, we keep saying well fix the pipeline but nothing changes and now customers are complaining, someone needs to actually own this"}
]}
JSON

say "ESCALATION SUMMARY  @~^_-1  — the user's heated last turn → a clean, de-heated, forwardable summary"
echo -n "  ^_-1   (raw rant)      => "; "$NLIR" -e "^_-1"   --context-file "$CTX" --quiet | fold -s -w 84 | sed '2,$s/^/       /'
echo -n "  @~^_-1 (the escalation) => "; "$NLIR" -e "@~^_-1" --context-file "$CTX" --quiet | fold -s -w 84 | sed '2,$s/^/       /'

say "~ keeps the facts + the ask; @ files the emotion as 'frustration'. #32's register×length plane, on a live message."
