#!/usr/bin/env bash
# nlir-golf (target / reverse) · msm0 · #41 — "@ reconstructs an out-of-office handoff"
#
# The everyday "I'm out, here's the cover plan" pi turn — an OOO notice with the
# coverage arrangements, from a compact seed:
#
#   TARGET : Please be advised that I will be on vacation next week and will not have
#            access to a laptop. I have documented the deployment runbook in the wiki,
#            and Priya has kindly agreed to cover any incidents that may arise during
#            my absence. Please direct any urgent matters to her.
#   nlir   : @'heads up im out on vacation next week with no laptop. ive documented
#            the deploy runbook in the wiki and priya has agreed to cover any incidents.
#            please route anything urgent to her'
#            (177 chars -> a polished OOO handoff: absence / docs / cover / routing)
#
# The seed keeps the four beats (out next week, no laptop, runbook documented, Priya
# covers → route urgent to her); @ raises the register while keeping the practical
# routing instruction that makes the handoff actionable.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
CFG="${NLIR_CONFIG:-config.example.yaml}"
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
say 'TARGET: an "out on vacation, runbook in the wiki, Priya covers, route urgent to her" OOO note'
printf "  => "
"$NLIR" --config "$CFG" --mode llm -e "@'heads up im out on vacation next week with no laptop. ive documented the deploy runbook in the wiki and priya has agreed to cover any incidents. please route anything urgent to her'" --quiet
say "absence + docs + cover + routing preserved — the daily out-of-office handoff turn."
