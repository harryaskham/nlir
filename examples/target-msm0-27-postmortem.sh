#!/usr/bin/env bash
# nlir-golf (target / reverse) · msm0 · #27 — "@ reconstructs a postmortem note"
#
# The everyday "here's what broke, why, and what we did" pi turn — a root-cause note
# with the fix, from a compact seed:
#
#   TARGET : Last night's outage was caused by a configuration error: the connection
#            pool size was incorrectly set to 5 instead of 50 during deployment. The
#            change has been reverted, and a validation check has been implemented to
#            detect out-of-range pool size values going forward.
#   nlir   : @'last nights outage was a config typo — pool size set to 5 not 50 in
#            the deploy. reverted it and added a validation check to catch
#            out-of-range pool sizes'
#            (152 chars -> a clean cause / fix / prevention postmortem note)
#
# The seed keeps the three postmortem beats (root cause, the fix, the prevention);
# @ preserves the exact numbers (5 vs 50) and the "going forward" safeguard framing.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
CFG="${NLIR_CONFIG:-config.example.yaml}"
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
say 'TARGET: a "outage was a pool-size typo (5 not 50), reverted + added validation" postmortem'
printf "  => "
"$NLIR" --config "$CFG" --mode llm -e "@'last nights outage was a config typo — pool size set to 5 not 50 in the deploy. reverted it and added a validation check to catch out-of-range pool sizes'" --quiet
say "cause + fix + prevention preserved, exact numbers kept — the daily postmortem-note turn."
