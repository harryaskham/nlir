#!/usr/bin/env bash
# nlir-golf (target / reverse) · msm0 · #45 — "@ reconstructs an accountability note"
#
# One of the hardest everyday turns — owning a mistake cleanly, with the fix and an
# apology, from a compact seed:
#
#   TARGET : I want to take responsibility for an error: the data included in
#            yesterday's report was inadvertently pulled from the staging environment
#            rather than production, which resulted in inaccurate figures. I am
#            currently re-running the analysis against production data and will provide
#            corrected figures within the hour. I apologize for any confusion.
#   nlir   : @'i need to own something — the data i shared in yesterdays report was
#            pulled from staging by mistake so the numbers are off. im re-running
#            against production now and will send corrected figures within the hour.
#            sorry for the confusion'
#            (233 chars -> a clean accountability note: own it / fix / apologise)
#
# The seed keeps the three beats (I made a mistake / here's the fix in progress /
# sorry); @ raises the register without hedging the ownership — accountability lands
# only when it's direct, and @ keeps the "I want to take responsibility" up front.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
CFG="${NLIR_CONFIG:-config.example.yaml}"
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
say 'TARGET: an "I own it — report data was from staging, re-running against prod, sorry" accountability note'
printf "  => "
"$NLIR" --config "$CFG" --mode llm -e "@'i need to own something — the data i shared in yesterdays report was pulled from staging by mistake so the numbers are off. im re-running against production now and will send corrected figures within the hour. sorry for the confusion'" --quiet
say "ownership + fix-in-progress + apology preserved — accountability that lands because it's direct."
