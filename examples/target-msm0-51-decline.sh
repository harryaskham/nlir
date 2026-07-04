#!/usr/bin/env bash
# nlir-golf (target / reverse) · msm0 · #51 — "@ reconstructs a polite decline"
#
# One of the trickiest everyday turns — saying no gracefully while leaving a door open,
# from a compact seed:
#
#   TARGET : Thank you for considering me for this. However, I am currently at full
#            capacity with the migration project and would prefer not to take this on
#            without being able to give it my full attention. Could we revisit this in a
#            few weeks, or would it be possible to identify someone with more immediate
#            availability?
#   nlir   : @'thanks for thinking of me but im at capacity with the migration and dont
#            want to take this on half-heartedly. could we revisit in a couple weeks, or
#            find someone with bandwidth sooner?'
#            (177 chars -> a gracious decline: appreciation / the reason / two off-ramps)
#
# The seed keeps the appreciation, the honest reason (at capacity, won't do it justice),
# and the two off-ramps (revisit later OR someone else sooner); @ raises the register
# while keeping the "not no, just not now" — a decline that protects the relationship.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
CFG="${NLIR_CONFIG:-config.example.yaml}"
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
say 'TARGET: a "thanks, but I'\''m at capacity — revisit in a few weeks or find someone sooner?" polite decline'
printf "  => "
"$NLIR" --config "$CFG" --mode llm -e "@'thanks for thinking of me but im at capacity with the migration and dont want to take this on half-heartedly. could we revisit in a couple weeks, or find someone with bandwidth sooner?'" --quiet
say "appreciation + honest reason + two off-ramps preserved — a decline that protects the relationship."
