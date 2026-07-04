#!/usr/bin/env bash
# nlir-golf (target / reverse) · msm0 · #37 — "@ reconstructs a delegation / growth handoff"
#
# A meaningful everyday turn — handing someone real ownership as a growth step, with
# support, from a compact seed:
#
#   TARGET : I have decided to transfer ownership of the incident-response rotation to
#            you. You have consistently demonstrated sound judgment under pressure, and
#            assuming full end-to-end responsibility for this rotation will serve as a
#            valuable growth opportunity. I am happy to shadow the first few incidents
#            should that be helpful.
#   nlir   : @'ive decided to hand the incident-response rotation over to you — youve
#            shown solid judgment under pressure, and owning it end-to-end will be a
#            good growth step. happy to shadow the first few if that helps'
#            (206 chars -> a polished delegation: the handoff, the why, the support)
#
# The seed keeps the three beats (I'm giving you this / here's why you've earned it /
# I've got your back); @ raises the register while keeping the vote of confidence —
# a delegation that reads as trust, not offloading.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
CFG="${NLIR_CONFIG:-config.example.yaml}"
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
say 'TARGET: a "handing you the on-call rotation — you'\''ve earned it, I'\''ll shadow the first few" delegation'
printf "  => "
"$NLIR" --config "$CFG" --mode llm -e "@'ive decided to hand the incident-response rotation over to you — youve shown solid judgment under pressure, and owning it end-to-end will be a good growth step. happy to shadow the first few if that helps'" --quiet
say "handoff + rationale + support preserved — a delegation that reads as trust, not offloading."
