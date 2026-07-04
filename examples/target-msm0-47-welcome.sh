#!/usr/bin/env bash
# nlir-golf (target / reverse) · msm0 · #47 — "@ reconstructs a new-hire welcome"
#
# The warm everyday turn — welcoming someone on day one with the practical bits and an
# open door, from a compact seed:
#
#   TARGET : Welcome to the team. Your development environment has been set up, and the
#            onboarding documentation has been placed in your inbox. Please feel free to
#            schedule time with me at your convenience this week — I would be glad to
#            walk you through the architecture and address any questions you may have.
#   nlir   : @'welcome to the team! ive set up your dev environment and dropped the
#            onboarding docs in your inbox. grab time with me this week whenever suits —
#            id love to walk you through the architecture and answer any questions'
#            (216 chars -> a warm, practical welcome: greeting / logistics / open door)
#
# The seed keeps the welcome, the logistics (env set up, docs in inbox), and the offer
# (grab time, architecture walkthrough); @ raises the register while keeping the
# genuine "I'd love to" — a welcome should read as warmth, not process.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
CFG="${NLIR_CONFIG:-config.example.yaml}"
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
say 'TARGET: a "welcome! env is set up, docs in your inbox, grab time for an architecture walkthrough" note'
printf "  => "
"$NLIR" --config "$CFG" --mode llm -e "@'welcome to the team! ive set up your dev environment and dropped the onboarding docs in your inbox. grab time with me this week whenever suits — id love to walk you through the architecture and answer any questions'" --quiet
say "greeting + logistics + open door preserved, warmth kept — a welcome that reads as care, not process."
