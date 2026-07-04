#!/usr/bin/env bash
# nlir-golf (target / reverse) · msm0 · #24 — "@ reconstructs a feature handoff"
#
# The everyday "I'm handing this off, here's the state" pi turn — what's done, what's
# rough, and a landmine to watch, from a compact seed:
#
#   TARGET : This is to hand off the search feature. The indexing pipeline is
#            complete and has been deployed; however, relevance tuning remains in an
#            early stage and requires further refinement. Additionally, there is an
#            intermittently failing test in the ranking suite that warrants
#            investigation.
#   nlir   : @'handing off the search feature — indexing pipeline done and deployed,
#            but relevance tuning still rough and theres a flaky test in the ranking
#            suite to look at'
#            (156 chars -> a structured handoff: done / rough / watch-out)
#
# The seed keeps three handoff beats (shipped, incomplete, landmine); @ preserves
# the status distinctions (done vs rough vs flaky) that make a handoff actionable.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
CFG="${NLIR_CONFIG:-config.example.yaml}"
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
say 'TARGET: a "handing off search — pipeline done, tuning rough, flaky ranking test" handoff'
printf "  => "
"$NLIR" --config "$CFG" --mode llm -e "@'handing off the search feature — indexing pipeline done and deployed, but relevance tuning still rough and theres a flaky test in the ranking suite to look at'" --quiet
say "done / rough / watch-out distinctions preserved — the daily handoff turn."
