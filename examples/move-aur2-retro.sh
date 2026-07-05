#!/usr/bin/env bash
# nlir POWER-MOVE (aur-2) — "the retro": a sprint retrospective in one message.
#
# THE MOVE (reusable):
#     @ & [ WHAT_WORKED , WHAT_DIDNT , WHAT_TO_CHANGE ]
#     └ formal   └ &[...] weaves the three questions of a retrospective into one note
#
# The team-level companion to the postmortem (which owns ONE mistake): a retro looks back over a
# whole sprint/period and answers the three questions that make retros useful — what went well
# (keep doing it), what didn't (name it plainly), and the concrete change you'll make next time.
#
# Filled example:
#   @&['what worked: the daily standups kept everyone unblocked and shipping',
#      'what did not: we underestimated the data migration and it slipped a week',
#      'next time: we timebox spikes to two days and pad any migration estimate by fifty percent']
#
# Real output (claude-sonnet-5):
#   "What worked well was that daily stand-up meetings kept the team unblocked and enabled consistent
#    progress. What did not go as planned was the data migration, which was underestimated and resulted
#    in a one-week delay. Going forward, we will timebox exploratory spikes to two days and increase
#    all migration estimates by fifty percent to account for such risks."
#
# WHY IT WORKS: the third slot is the payoff — a retro without a concrete change is just venting.
# Ending on the specific thing you'll do differently turns reflection into an improvement.
#
# REUSE IT:  @&[<what worked>, <what didn't>, <the concrete change next time>]
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR="@&['what worked: the daily standups kept everyone unblocked and shipping','what did not: we underestimated the data migration and it slipped a week','next time: we timebox spikes to two days and pad any migration estimate by fifty percent']"

echo "move:       the retro -- @&[what worked, what didn't, what to change]"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
