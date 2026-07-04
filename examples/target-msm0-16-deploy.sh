#!/usr/bin/env bash
# nlir-golf (target / reverse) · msm0 · #16 — "@ reconstructs a deploy status"
#
# The everyday "it worked on staging, prod tonight" pi turn — a two-stage status
# from a compact seed:
#
#   TARGET : The migration script executed successfully in the staging environment.
#            It is scheduled to run in production during tonight's maintenance window.
#   nlir   : @'migration script worked perfectly on staging, will run on prod
#            during tonight maintenance window'
#            (95 chars -> a clean two-sentence status)
#
# The seed carries the result (staging pass) + the plan (prod tonight); @ splits
# it into two crisp sentences and normalises "prod" -> "production".
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
CFG="${NLIR_CONFIG:-config.example.yaml}"
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
say 'TARGET: a "worked on staging, running prod tonight" deploy status'
printf "  => "
"$NLIR" --config "$CFG" --mode llm -e "@'migration script worked perfectly on staging, will run on prod during tonight maintenance window'" --quiet
say "result + plan preserved, prod->production normalised — the daily deploy-status turn."
