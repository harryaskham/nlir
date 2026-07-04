#!/usr/bin/env bash
# nlir-golf (target / reverse) · msm0 · #10 — "@ reconstructs an apology + new ETA"
#
# The everyday "sorry, here's why, here's the new date" turn — three beats from a
# compact seed:
#
#   TARGET : Apologies for the delay. I was called to assist with an incident;
#            I will return the reviewed pull request by end of day tomorrow.
#   nlir   : @'sorry for the delay, got pulled into an incident, will have the
#            reviewed PR back by EOD tmrw'
#            (89 chars -> a polished apology / reason / new-ETA line)
#
# The seed carries apology + reason + commitment as fragments; @ supplies the
# contrite register and the connective grammar.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
CFG="${NLIR_CONFIG:-config.example.yaml}"
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
say 'TARGET: an "apology / reason / new ETA" delay notice'
printf "  => "
"$NLIR" --config "$CFG" --mode llm -e "@'sorry for the delay, got pulled into an incident, will have the reviewed PR back by EOD tmrw'" --quiet
say "three beats — apology, reason, commitment — reconstructed from fragments by @."
