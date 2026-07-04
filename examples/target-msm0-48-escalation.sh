#!/usr/bin/env bash
# nlir-golf (target / reverse) · msm0 · #48 — "@ reconstructs an escalation to a manager"
#
# The high-stakes everyday turn — escalating a recurring problem with a proposed path,
# from a compact seed:
#
#   TARGET : I am flagging this issue for visibility. We have postponed the launch date
#            twice due to ongoing changes to the API dependency. I recommend that we
#            either finalize and freeze the API contract or postpone the launch to next
#            quarter. Could we schedule a discussion to review these options?
#   nlir   : @'flagging this for visibility — weve slipped the launch date twice now
#            because the api dependency keeps changing under us. i think we need to
#            either freeze the api contract or push the launch to next quarter. can we
#            discuss options?'
#            (232 chars -> a measured escalation: the pattern / the cause / two options / the ask)
#
# The seed keeps the pattern (slipped twice), the root cause (API keeps changing), the
# two options (freeze the contract OR push the date), and the ask (let's discuss); @
# raises the register into a calm, structured escalation — not a complaint, a decision
# request.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
CFG="${NLIR_CONFIG:-config.example.yaml}"
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
say 'TARGET: a "slipped twice on the API dependency — freeze the contract or push to next quarter?" escalation'
printf "  => "
"$NLIR" --config "$CFG" --mode llm -e "@'flagging this for visibility — weve slipped the launch date twice now because the api dependency keeps changing under us. i think we need to either freeze the api contract or push the launch to next quarter. can we discuss options?'" --quiet
say "pattern + cause + two options + the ask preserved — an escalation that's a decision request, not a complaint."
