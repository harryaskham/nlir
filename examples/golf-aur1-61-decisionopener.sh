#!/usr/bin/env bash
# nlir-golf · aur1 · #61 — "the decision opener" (recommend it, then put it to the room)
#
# How you open a decision cleanly: state your recommendation, then frame the question the
# group is actually deciding. `[@x, x?]` does both from one idea — `@x` gives the formal
# RECOMMENDATION (your position, dressed for a doc) and `x?` gives the DECISION QUESTION
# (the same idea flipped into the yes/no the meeting will vote on). Lead, then invite.
#
#   DECISION OPENER   [ @x , x? ]
#     idea "we should freeze the api contract before the launch"
#     @x  → "The API contract should be finalized prior to launch."   ← the RECOMMENDATION
#     x?  → "Should we freeze the API contract before the launch?"     ← the QUESTION
#
# Two poles of the MODE axis in one card: `@x` asserts (here's what I think), `x?`
# interrogates (here's what we're deciding). It's the assert-and-ask move — you go on
# record with a position AND hand the room the exact question, so discussion starts
# focused instead of wandering. Distinct from #56 options→decision (a whole list of
# choices): here it's one recommendation, put up for the vote.
#
# Run:  ./examples/golf-aur1-61-decisionopener.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
C='we should freeze the api contract before the launch'

say "DECISION OPENER  [@x, x?]  — the formal RECOMMENDATION (@x) + the DECISION QUESTION for the room (x?)"
echo   "  idea: $C"
echo -n "  @x (RECOMMENDATION) => "; "$NLIR" -e "@'$C'" --quiet | fold -s -w 84 | sed '2,$s/^/       /'
echo -n "  x? (the QUESTION)   => "; "$NLIR" -e "'$C'?" --quiet | fold -s -w 84 | sed '2,$s/^/       /'

say "Both poles of the MODE axis: @x asserts, x? interrogates. Assert-and-ask — go on record, then hand over the question."
