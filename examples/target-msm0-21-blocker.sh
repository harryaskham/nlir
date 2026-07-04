#!/usr/bin/env bash
# nlir-golf (target / reverse) · msm0 · #21 — "@ reconstructs a blocker escalation"
#
# The everyday "I'm stuck, here's what I tried, I need help" pi turn — a blocker
# escalation with the attempts and the ask, from a compact seed:
#
#   TARGET : We are currently blocked on the payments integration. The sandbox
#            environment is returning 403 errors despite two attempts to regenerate
#            the API keys. We would appreciate the platform team's assistance in
#            investigating this issue.
#   nlir   : @'blocked on payments integration — sandbox returns 403s despite
#            regenerating api keys twice, need platform team to take a look'
#            (124 chars -> a clear escalation with symptom, attempts, and the ask)
#
# The seed keeps the three escalation beats (what's blocked / what was tried / who
# to pull in); @ turns "need X to take a look" into a courteous request for help.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
CFG="${NLIR_CONFIG:-config.example.yaml}"
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
say 'TARGET: a "blocked on payments, tried regenerating keys, need the platform team" escalation'
printf "  => "
"$NLIR" --config "$CFG" --mode llm -e "@'blocked on payments integration — sandbox returns 403s despite regenerating api keys twice, need platform team to take a look'" --quiet
say "symptom + attempts + ask preserved, 'need X' -> courteous request — the daily escalation turn."
