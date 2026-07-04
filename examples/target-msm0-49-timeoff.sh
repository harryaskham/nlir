#!/usr/bin/env bash
# nlir-golf (target / reverse) · msm0 · #49 — "@ reconstructs a time-off request"
#
# The everyday "I'd like some days off, and I've got it covered" pi turn — a PTO
# request with the courtesy of having checked, from a compact seed:
#
#   TARGET : I would like to request Thursday and Friday off next week to attend to a
#            family matter. I have confirmed that there is nothing critical scheduled on
#            the calendar for those days, and I will ensure that my open pull requests
#            are merged or handed off prior to my departure.
#   nlir   : @'id like to take thursday and friday off next week for a family thing.
#            ive checked and theres nothing critical on the calendar those days, and ill
#            make sure my open PRs are merged or handed off before i go'
#            (200 chars -> a considerate PTO request: the ask / the check / the handoff)
#
# The seed keeps the ask (Thu+Fri off), the reason (family), and the two courtesies
# (nothing critical scheduled / PRs handled first); @ raises the register while keeping
# the "I've already thought about the impact" — which is what makes a request easy to
# grant.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
CFG="${NLIR_CONFIG:-config.example.yaml}"
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
say 'TARGET: a "Thu+Fri off for family, nothing critical scheduled, PRs handed off first" PTO request'
printf "  => "
"$NLIR" --config "$CFG" --mode llm -e "@'id like to take thursday and friday off next week for a family thing. ive checked and theres nothing critical on the calendar those days, and ill make sure my open PRs are merged or handed off before i go'" --quiet
say "ask + reason + two courtesies preserved — a request easy to grant because the impact is already handled."
