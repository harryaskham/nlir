#!/usr/bin/env bash
# nlir POWER-MOVE (aur-2) — "the postmortem note": own the miss, name the cause, show the prevention.
#
# THE MOVE (reusable):
#     @ & [ OWN_THE_MISS , THE_ROOT_CAUSE , THE_PREVENTION ]
#     └ formal   └ &[...] weaves the three beats of a graceful accountability note
#
# The hardest message to write well: take responsibility cleanly, state the root cause without
# excuses, and show the concrete fix so it can't recur. One line = a postmortem note that builds
# trust instead of spending it.
#
# Filled example:
#   @&['i own the incident, my change took down checkout for twenty minutes',
#      'the root cause was a missing null check on the new coupon path',
#      'ive added a test for that path and a canary deploy step so it cannot recur']
#
# Real output (claude-sonnet-5):
#   "I take full responsibility for this incident. My change caused a twenty-minute outage of the
#    checkout system, and the root cause was identified as a missing null check on the new coupon
#    path. I have since added a test covering that path, as well as a canary deployment step, to
#    prevent this issue from recurring."
#
# REUSE IT:  @&[<own the miss>, <the root cause>, <the prevention>]
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR="@&['i own the incident, my change took down checkout for twenty minutes','the root cause was a missing null check on the new coupon path','ive added a test for that path and a canary deploy step so it cannot recur']"

echo "move:       the postmortem note -- @&[own the miss, root cause, prevention]"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
