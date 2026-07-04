#!/usr/bin/env bash
# nlir-golf (target / reverse) · msm0 · #40 — "@ reconstructs a team thank-you"
#
# A warm everyday turn — closing out a big sprint with genuine team appreciation,
# from a compact seed:
#
#   TARGET : Thank you all for an outstanding sprint. We successfully delivered the
#            largest release in the product's history and resolved a significant
#            concurrency issue, all while maintaining sustainable working hours. I am
#            proud of this team's achievement.
#   nlir   : @'thanks everyone for an incredible sprint. we shipped the biggest
#            release in the products history, fixed a nasty concurrency bug, and did
#            it without a single late night. proud of this team'
#            (185 chars -> a polished team thank-you keeping the three wins)
#
# The seed keeps the three concrete wins (biggest release / nasty bug fixed / no late
# nights) and the pride; @ raises the register while keeping the warmth — a thank-you
# that names what the team actually did, not a generic "great job".
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
CFG="${NLIR_CONFIG:-config.example.yaml}"
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
say 'TARGET: a "thanks team — biggest release, fixed the concurrency bug, no late nights, proud" note'
printf "  => "
"$NLIR" --config "$CFG" --mode llm -e "@'thanks everyone for an incredible sprint. we shipped the biggest release in the products history, fixed a nasty concurrency bug, and did it without a single late night. proud of this team'" --quiet
say "three concrete wins + the pride preserved — team thanks that names what they did."
