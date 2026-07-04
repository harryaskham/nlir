#!/usr/bin/env bash
# nlir-golf (target / reverse) · msm0 · #25 — "@ reconstructs a spike proposal"
#
# The everyday "let's de-risk before we commit" pi turn — a proposal with a
# safeguard rationale, from a compact seed:
#
#   TARGET : Prior to committing to the full rewrite, we should timebox a two-week
#            spike to validate the proposed approach. This will help ensure we do
#            not invest a full quarter only to discover that the anticipated
#            performance gains do not materialize.
#   nlir   : @'before committing to the full rewrite, lets timebox a two-week spike
#            to validate the approach — dont want to sink a quarter in and find the
#            perf gains arent there'
#            (161 chars -> a polished proposal with the risk rationale)
#
# The seed keeps the proposal (timebox a spike) + the risk it hedges (a wasted
# quarter); @ frames it as a recommendation and preserves the "so we don't…" logic.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
CFG="${NLIR_CONFIG:-config.example.yaml}"
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
say 'TARGET: a "timebox a two-week spike before the rewrite, to de-risk a wasted quarter" proposal'
printf "  => "
"$NLIR" --config "$CFG" --mode llm -e "@'before committing to the full rewrite, lets timebox a two-week spike to validate the approach — dont want to sink a quarter in and find the perf gains arent there'" --quiet
say "proposal + risk rationale preserved — the daily de-risking turn."
