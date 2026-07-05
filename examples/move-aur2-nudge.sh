#!/usr/bin/env bash
# nlir POWER-MOVE (aur-2) — "the nudge": a warm, low-pressure follow-up.
#
# THE MOVE (reusable — the : leading op keeps it friendly):
#     : & [ THE_GENTLE_REMINDER , WHY_IT_MATTERS , THE_LOW_PRESSURE_ASK ]
#     └ warm   └ &[...] weaves a reminder that lands as a friend, not a manager
#
# Chasing something without being pushy: a soft reminder, a quiet reason it matters, and a
# low-pressure ask. The : leading op does the work — it keeps the whole thing warm; swap it for @
# and the same three beats turn into a stiff formal chase.
#
# Filled example:
#   :&['just a gentle nudge on the design doc review',
#      'it is quietly blocking two people from starting',
#      'no rush today but would love your eyes on it by tomorrow']
#
# Real output (claude-sonnet-5):
#   "Hey, just a friendly reminder about looking at the design document. Two people can't start
#    their work until you check it, but that's okay for today — it would be great if you could take
#    a look by tomorrow!"
#
# REUSE IT:  :&[<gentle reminder>, <why it quietly matters>, <the low-pressure ask>]
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR=":&['just a gentle nudge on the design doc review','it is quietly blocking two people from starting','no rush today but would love your eyes on it by tomorrow']"

echo "move:       the nudge -- :&[gentle reminder, why it matters, low-pressure ask]  (: warm)"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
