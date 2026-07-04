#!/usr/bin/env bash
# nlir-golf (target / reverse) · msm0 · #44 — "@ reconstructs a decision reversal"
#
# The everyday "actually, let's not — here's why I changed my mind" pi turn — a
# reversal with the reasoning and a re-open condition, from a compact seed:
#
#   TARGET : After further review, we have decided to postpone the Redis migration at
#            this time. An analysis of the current metrics indicates that the existing
#            PostgreSQL setup is adequately handling the load, and migrating now would
#            constitute premature optimization. We will revisit this decision if we
#            encounter genuine scaling challenges in the future.
#   nlir   : @'actually lets hold off on the redis migration for now. i dug into the
#            numbers and our current postgres setup handles the load fine — migrating
#            would be premature optimization. lets revisit if we hit real scaling pain'
#            (218 chars -> a polished reversal: the call / the evidence / the re-open trigger)
#
# The seed keeps the reversal (hold off), the evidence (numbers say Postgres is fine),
# and the condition (revisit on real scaling pain); @ frames it as a considered
# decision — "after further review" — rather than a flip-flop.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
CFG="${NLIR_CONFIG:-config.example.yaml}"
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
say 'TARGET: an "actually hold off on Redis — Postgres handles the load, revisit on real scaling pain" reversal'
printf "  => "
"$NLIR" --config "$CFG" --mode llm -e "@'actually lets hold off on the redis migration for now. i dug into the numbers and our current postgres setup handles the load fine — migrating would be premature optimization. lets revisit if we hit real scaling pain'" --quiet
say "reversal + evidence + re-open trigger preserved — a considered decision, not a flip-flop."
