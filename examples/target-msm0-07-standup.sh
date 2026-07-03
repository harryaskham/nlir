#!/usr/bin/env bash
# nlir-golf (target / reverse) · msm0 · #07 — "@ reconstructs a structured standup"
#
# @ doesn't just polish a line — it rebuilds STRUCTURE from a compact seed. A
# yesterday/today/blocked standup from shorthand:
#
#   TARGET : Yesterday, I resolved the authentication bug. Today, I am working on
#            the deployment pipeline; however, I am currently blocked due to a lack
#            of access to the staging environment.
#   nlir   : @'ystd fixed auth bug, today on deploy pipeline, blocked on staging access'
#            (67 chars -> a full 3-part standup)
#
# The seed carries the three beats (done / doing / blocked) as fragments; @ infers
# the standup shape and supplies the grammar. The daily status-update pi turn.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
CFG="${NLIR_CONFIG:-config.example.yaml}"
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
say 'TARGET: a 3-part "yesterday / today / blocked" standup update'
printf "  => "
"$NLIR" --config "$CFG" --mode llm -e "@'ystd fixed auth bug, today on deploy pipeline, blocked on staging access'" --quiet
say "@ rebuilds structure, not just register — the daily status-update turn."
