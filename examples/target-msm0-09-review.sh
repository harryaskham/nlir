#!/usr/bin/env bash
# nlir-golf (target / reverse) · msm0 · #09 — "@ reconstructs a nuanced review request"
#
# The rich everyday pi turn: a review request that carries context AND a hedge.
# @ rebuilds all of it — the ask, three facts, and the uncertainty:
#
#   TARGET : Please review the authentication refactor at your earliest
#            convenience. The token logic has been separated into its own module,
#            and tests have been added; however, I am uncertain whether the error
#            handling approach is appropriate and would appreciate your feedback.
#   nlir   : @'look at auth refactor when free — split token logic to own module,
#            added tests, unsure on error handling'
#            (98 chars -> a full multi-clause request with a hedge)
#
# Note the "unsure on error handling" fragment survives as a proper hedge clause —
# @ preserves stance (uncertainty), not just facts.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
CFG="${NLIR_CONFIG:-config.example.yaml}"
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
say 'TARGET: a review request with context + a hedge on error handling'
printf "  => "
"$NLIR" --config "$CFG" --mode llm -e "@'look at auth refactor when free — split token logic to own module, added tests, unsure on error handling'" --quiet
say "@ preserves stance (the hedge), not just facts — the nuanced review-request turn."
