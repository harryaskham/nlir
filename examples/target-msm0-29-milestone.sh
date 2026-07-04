#!/usr/bin/env bash
# nlir-golf (target / reverse) · msm0 · #29 — "@ reconstructs a milestone celebration"
#
# The everyday "we hit a big number, credit to the team" pi turn — a celebration
# with the metric and the credit, from a compact seed:
#
#   TARGET : We reached a significant milestone today, surpassing 10,000 daily
#            active users—double last quarter's figure. This achievement reflects
#            the dedication of the entire team, whose onboarding improvements were
#            instrumental in driving this growth.
#   nlir   : @'huge milestone today — hit 10k daily active users, double last
#            quarter. massive credit to the whole team for the onboarding
#            improvements that drove it'
#            (150 chars -> a polished celebration keeping the metric + the credit)
#
# The seed keeps the number (10k DAU, double last quarter) and the attribution
# (team / onboarding); @ raises the register while keeping the warmth of the credit.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
CFG="${NLIR_CONFIG:-config.example.yaml}"
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
say 'TARGET: a "hit 10k DAU, double last quarter, credit to the team" milestone note'
printf "  => "
"$NLIR" --config "$CFG" --mode llm -e "@'huge milestone today — hit 10k daily active users, double last quarter. massive credit to the whole team for the onboarding improvements that drove it'" --quiet
say "metric + attribution preserved, warmth kept — the milestone-celebration turn."
