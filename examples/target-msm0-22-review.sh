#!/usr/bin/env bash
# nlir-golf (target / reverse) · msm0 · #22 — "@ reconstructs a code-review comment"
#
# The everyday "I reviewed your PR, here's the one real issue" pi turn — nits plus a
# blocking concern, from a compact seed:
#
#   TARGET : I have reviewed the pull request and provided several comments. Most
#            are minor stylistic suggestions; however, the error handling within the
#            retry loop warrants further examination prior to merging, as it may
#            currently suppress exceptions silently.
#   nlir   : @'left a few comments on the PR — mostly nits, but the error handling
#            in the retry loop needs a second look before merge, could swallow
#            exceptions silently'
#            (150 chars -> a review comment separating nits from the blocker)
#
# The seed keeps the review shape (mostly-nits BUT one real issue); @ preserves the
# "however" that marks the blocking concern — the part a reviewer must not lose.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
CFG="${NLIR_CONFIG:-config.example.yaml}"
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
say 'TARGET: a "mostly nits but the retry-loop error handling is a blocker" review comment'
printf "  => "
"$NLIR" --config "$CFG" --mode llm -e "@'left a few comments on the PR — mostly nits, but the error handling in the retry loop needs a second look before merge, could swallow exceptions silently'" --quiet
say "nits-vs-blocker distinction preserved (the 'however') — the daily code-review turn."
