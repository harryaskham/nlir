#!/usr/bin/env bash
# nlir-golf (target / reverse) · msm0 · #63 — "@ reconstructs an owned judgment call"
#
# The turn that separates good engineers from great ones — owning a unilateral decision made
# under pressure, without either grovelling or defending, from a compact seed:
#
#   TARGET : I want to inform you that I made a decision independently last night without
#            consulting you beforehand, as the site was experiencing an outage and you were
#            unavailable at the time. I rolled back the release to the last known-good version,
#            which resolved the outage. I recognize, however, that rolling back your feature was
#            not a decision I should have made unilaterally. I am happy to discuss this further,
#            and I will re-deploy the feature whenever you are ready.
#   nlir   : @'heads up — i made a call last night without looping you in first, because the site
#            was down and you were offline. i rolled back the release to the last known-good
#            version. it fixed the outage, but i know rolling back your feature wasnt mine to
#            decide unilaterally. happy to talk through it, and ill re-deploy whenever youre ready'
#            (322 chars -> an owned call: what I did / why / the acknowledgment / the repair)
#
# The seed keeps the action (rolled back your release), the justification (site down, you
# offline), the honest acknowledgment (wasn't mine to decide alone), and the repair (let's talk,
# I'll re-deploy on your word); @ raises the register while keeping the ownership — an after-
# action note lands when it neither over-apologises nor defends, and @ holds that even keel.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
CFG="${NLIR_CONFIG:-config.example.yaml}"
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
say 'TARGET: a "site was down, you were offline, I rolled back your release — not mine to decide alone, let'\''s talk" note'
printf "  => "
"$NLIR" --config "$CFG" --mode llm -e "@'heads up — i made a call last night without looping you in first, because the site was down and you were offline. i rolled back the release to the last known-good version. it fixed the outage, but i know rolling back your feature wasnt mine to decide unilaterally. happy to talk through it, and ill re-deploy whenever youre ready'" --quiet
say "action + justification + acknowledgment + repair preserved — an owned call, neither grovelling nor defending."
