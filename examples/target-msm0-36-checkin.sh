#!/usr/bin/env bash
# nlir-golf (target / reverse) · msm0 · #36 — "@ reconstructs a wellbeing check-in"
#
# A caring everyday turn — checking in on someone's workload before they burn out,
# from a compact seed:
#
#   TARGET : I wanted to check in regarding your current workload. As you have been
#            on call for two consecutive weeks, I want to ensure we are not placing
#            undue strain on you in the lead-up to the launch.
#   nlir   : @'wanted to check in on your workload — youve been on-call two weeks
#            straight, and i want to make sure were not burning you out before the
#            launch'
#            (145 chars -> a warm, professional wellbeing check-in)
#
# The seed keeps the concern (workload), the observation (two weeks on-call), and the
# timing (before launch); @ raises the register while keeping the care — the whole
# point of a check-in is that it reads as genuine, not managerial.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
CFG="${NLIR_CONFIG:-config.example.yaml}"
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
say 'TARGET: a "checking in on your workload — two weeks on-call, don'\''t want to burn you out" note'
printf "  => "
"$NLIR" --config "$CFG" --mode llm -e "@'wanted to check in on your workload — youve been on-call two weeks straight, and i want to make sure were not burning you out before the launch'" --quiet
say "concern + observation + timing preserved, warmth kept — the wellbeing-check-in turn."
