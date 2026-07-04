#!/usr/bin/env bash
# nlir-golf (target / reverse) · msm0 · #23 — "@ reconstructs design feedback"
#
# The everyday "the redesign is good, but one thing" pi turn — praise plus a
# specific bug plus an urgency, from a compact seed:
#
#   TARGET : The onboarding redesign appears clean, and the copy is significantly
#            clearer. One issue to note: the progress bar disappears on step 3,
#            which creates the impression that the form has reset. This should be
#            addressed prior to launch.
#   nlir   : @'onboarding redesign looks clean, copy much clearer; one thing —
#            progress bar disappears on step 3, feels like the form reset, worth
#            fixing before launch'
#            (150 chars -> polished feedback: praise, the specific bug, the urgency)
#
# The seed keeps praise + a precise repro (progress bar, step 3, feels-like-reset) +
# "before launch"; @ raises the register and keeps every specific — vague praise is
# useless, the detail is the feedback.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
CFG="${NLIR_CONFIG:-config.example.yaml}"
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
say 'TARGET: a "redesign looks good, but the progress bar breaks on step 3" feedback note'
printf "  => "
"$NLIR" --config "$CFG" --mode llm -e "@'onboarding redesign looks clean, copy much clearer; one thing — progress bar disappears on step 3, feels like the form reset, worth fixing before launch'" --quiet
say "praise + precise repro + urgency preserved — the daily design-feedback turn."
