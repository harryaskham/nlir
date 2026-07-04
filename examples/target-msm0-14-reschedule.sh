#!/usr/bin/env bash
# nlir-golf (target / reverse) · msm0 · #14 — "@ reconstructs a reschedule"
#
# The everyday "let's move the meeting, here's why" pi turn — a reschedule with two
# reasons, from a compact seed:
#
#   TARGET : I would like to reschedule our sync to Thursday at 2:00 PM. I have a
#            conflict on Wednesday, and the new time will also allow me additional
#            time to prepare the relevant figures.
#   nlir   : @'move our sync to thu 2pm — conflict wed, and gives me time to prep
#            numbers'
#            (72 chars -> a polite reschedule with both reasons)
#
# The seed carries the new time + two reasons (conflict, prep); @ supplies the
# courteous framing and the exact "2:00 PM" normalisation.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
CFG="${NLIR_CONFIG:-config.example.yaml}"
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
say 'TARGET: a "move our sync to Thursday 2pm, here is why" reschedule'
printf "  => "
"$NLIR" --config "$CFG" --mode llm -e "@'move our sync to thu 2pm — conflict wed, and gives me time to prep numbers'" --quiet
say "new time + two reasons preserved — the daily reschedule turn."
