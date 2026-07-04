#!/usr/bin/env bash
# nlir-golf (target / reverse) · msm0 · #33 — "@ reconstructs a project kickoff"
#
# The everyday "starting X, here's the goal, want to own a piece?" pi turn — a
# kickoff with a target and a delegation ask, from a compact seed:
#
#   TARGET : We will be initiating the search revamp next week. The objective is to
#            achieve sub-100ms response times along with typo tolerance. I will take
#            ownership of the indexing component, and I would welcome your involvement
#            in leading ranking and relevance, should you be available to take this on.
#   nlir   : @'kicking off the search revamp next week. goal is sub-100ms results and
#            typo tolerance. ill own indexing, would love for u to take ranking and
#            relevance if ur up for it'
#            (168 chars -> a polished kickoff: timeline / goal / ownership split)
#
# The seed keeps the plan (revamp next week), the metric (sub-100ms + typo tolerance),
# and the split (I own indexing, you own ranking); @ turns "would love for u to…" into
# a warm-but-professional delegation ask.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
CFG="${NLIR_CONFIG:-config.example.yaml}"
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
say 'TARGET: a "kicking off search revamp, sub-100ms goal, I own indexing, you take ranking?" kickoff'
printf "  => "
"$NLIR" --config "$CFG" --mode llm -e "@'kicking off the search revamp next week. goal is sub-100ms results and typo tolerance. ill own indexing, would love for u to take ranking and relevance if ur up for it'" --quiet
say "timeline + goal + ownership split preserved — the daily project-kickoff turn."
