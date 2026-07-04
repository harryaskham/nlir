#!/usr/bin/env bash
# nlir-golf (target / reverse) · msm0 · #69 — "@ reconstructs a launch go-decision"
#
# The decisive turn — a clear go call with the evidence and the one watched risk, from a compact
# seed:
#
#   TARGET : We are proceeding with Thursday's launch. The two blocking bugs have been resolved and
#            verified in staging, load testing has passed at three times the expected traffic, and
#            the rollback plan has been tested. The one remaining risk is the third-party payment
#            webhook, which will be closely monitored during the first 24 hours with an on-call
#            resource in place. Should any issues arise, we will fail over to the queue-and-retry
#            path. We are ready to proceed.
#   nlir   : @'decision: were a go for thursdays launch. the two blocking bugs are fixed and verified
#            in staging, load testing passed at 3x expected traffic, and the rollback plan is tested.
#            the one open risk is the third-party payment webhook, which well monitor closely for the
#            first 24 hours with someone on call. if it misbehaves, we fail over to the queue-and-retry
#            path. ship it'
#            (376 chars -> a go call: the decision / the evidence / the one risk / the mitigation / go)
#
# The seed keeps the decision (go for Thursday), the evidence (bugs fixed+verified, load test at 3x,
# rollback tested), the single open risk (the payment webhook), the mitigation (24h monitoring +
# on-call + fail over to queue-and-retry), and the call (ship it); @ raises the register into a
# crisp go-decision — a launch call lands when it's confident AND names the one risk, and @ keeps both.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
CFG="${NLIR_CONFIG:-config.example.yaml}"
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
say 'TARGET: a "go for Thursday — bugs fixed, load test at 3x, rollback tested; one risk (payment webhook), mitigated; ship it" call'
printf "  => "
"$NLIR" --config "$CFG" --mode llm -e "@'decision: were a go for thursdays launch. the two blocking bugs are fixed and verified in staging, load testing passed at 3x expected traffic, and the rollback plan is tested. the one open risk is the third-party payment webhook, which well monitor closely for the first 24 hours with someone on call. if it misbehaves, we fail over to the queue-and-retry path. ship it'" --quiet
say "decision + evidence + the one risk + mitigation + go preserved — a launch call that's confident and names the risk."
