#!/usr/bin/env bash
# nlir-golf (target / reverse) · msm0 · #34 — "@ reconstructs a customer incident update"
#
# The everyday "here's what happened, it's fixed, sorry" pi turn — a customer-facing
# incident note with cause, fix, prevention, and apology, from a compact seed:
#
#   TARGET : This is a brief update regarding Tuesday's outage. The root cause was
#            identified as a misconfigured cache setting, which has since been
#            resolved. We have also implemented additional monitoring to ensure any
#            recurrence would be detected immediately rather than going unnoticed. We
#            sincerely apologize for the disruption this caused to your team.
#   nlir   : @'quick update on tuesdays outage — root cause was a bad cache config
#            weve since fixed, added monitoring so it wont recur silently. really
#            sorry for the disruption to your team'
#            (172 chars -> a polished cause / fix / prevention / apology update)
#
# The seed keeps all four customer-update beats (what, fixed, prevented, sorry); @
# raises the register to customer-appropriate without dropping the apology's warmth.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
CFG="${NLIR_CONFIG:-config.example.yaml}"
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
say 'TARGET: a "update on Tuesday'\''s outage — bad cache config, fixed, added monitoring, sorry" customer note'
printf "  => "
"$NLIR" --config "$CFG" --mode llm -e "@'quick update on tuesdays outage — root cause was a bad cache config weve since fixed, added monitoring so it wont recur silently. really sorry for the disruption to your team'" --quiet
say "cause + fix + prevention + apology preserved — the customer-facing incident-update turn."
