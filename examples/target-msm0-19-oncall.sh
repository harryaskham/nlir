#!/usr/bin/env bash
# nlir-golf (target / reverse) · msm0 · #19 — "@ reconstructs an on-call proposal"
#
# The everyday "here's a process change I'm proposing, and why" pi turn — a
# recommendation with its justification, from a compact seed:
#
#   TARGET : We recommend dividing on-call coverage into two shorter shifts rather
#            than a full week-long rotation, as the current structure is
#            contributing to team burnout.
#   nlir   : @'we should split on-call into two shorter shifts instead of a full
#            week — current setup burns people out'
#            (99 chars -> a polished proposal with rationale)
#
# The seed carries the proposal + the reason (burnout); @ frames it as a
# recommendation and keeps the causal "as… is contributing to…" link.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
CFG="${NLIR_CONFIG:-config.example.yaml}"
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
say 'TARGET: a "split on-call into two shifts, current setup burns people out" proposal'
printf "  => "
"$NLIR" --config "$CFG" --mode llm -e "@'we should split on-call into two shorter shifts instead of a full week — current setup burns people out'" --quiet
say "proposal + causal rationale preserved — the daily process-change turn."
