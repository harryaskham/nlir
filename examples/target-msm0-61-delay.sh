#!/usr/bin/env bash
# nlir-golf (target / reverse) · msm0 · #61 — "@ reconstructs delay news to a customer"
#
# The turn nobody enjoys but everyone respects when done right — telling a customer their
# thing slipped, with the real reason and a firm new date, from a compact seed:
#
#   TARGET : I want to be transparent: the feature you requested will not be included in this
#            release. During testing, we identified a security vulnerability in the
#            authentication flow, and expediting the fix would risk exposing customer data.
#            The feature is scheduled to ship in the next release, in two weeks. I recognize
#            this may not be the outcome you were hoping for, and I apologize for the delay.
#   nlir   : @'i want to be upfront: the feature you asked about wont make this release. we
#            found a security issue in the auth flow during testing, and rushing the fix would
#            risk exposing customer data. itll ship in the next release in two weeks. i know
#            thats not what you wanted to hear, and im sorry for the delay'
#            (296 chars -> honest delay news: the news / the real reason / the firm date / the acknowledgment)
#
# The seed keeps the news (won't make this release), the real reason (a security issue, and why
# rushing is worse), the firm commitment (next release, two weeks), and the acknowledgment (not
# what you wanted, sorry); @ raises the register while keeping the candor — delay news is
# trusted when the reason is real and the new date is firm, and @ keeps both.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
CFG="${NLIR_CONFIG:-config.example.yaml}"
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
say 'TARGET: a "your feature slipped — we found a security issue, it ships in two weeks, sorry" delay note'
printf "  => "
"$NLIR" --config "$CFG" --mode llm -e "@'i want to be upfront: the feature you asked about wont make this release. we found a security issue in the auth flow during testing, and rushing the fix would risk exposing customer data. itll ship in the next release in two weeks. i know thats not what you wanted to hear, and im sorry for the delay'" --quiet
say "news + real reason + firm date + acknowledgment preserved — delay news trusted because the reason is real."
