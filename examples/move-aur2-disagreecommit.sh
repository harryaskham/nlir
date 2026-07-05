#!/usr/bin/env bash
# nlir POWER-MOVE (aur-2) — "the disagree-and-commit": put your reservation on record, accept the
# decision, and commit fully — the hallmark move of a healthy team, in one professional line.
#
# THE MOVE (reusable):
#     @ & [ "MY_RESERVATION" , "BUT_THE_CALL_IS_MADE" , "AND_IM_FULLY_IN" ]
#       @&[…] = formalize + weave three beats into one on-record statement
#     └──────── I still have a concern / the decision stands / I'm fully behind it
#
# Distinct from the respectful-dissent (which argues AGAINST + proposes an alternative): this one
# YIELDS gracefully — it records that you flagged the risk, accepts the call was made, and pledges
# your full commitment. Leaders use it constantly; nlir makes it one line.
#
# Filled example:
#   @&["I still think we are underestimating the migration risk",
#      "but the team has made the call to ship Monday",
#      "and I am fully behind making it succeed"]
#
# Real output (claude-sonnet-5):
#   "I continue to believe that we are underestimating the migration risk; nevertheless, the team has
#    decided to proceed with the Monday launch, and I am fully committed to ensuring its success."
#
# REUSE IT:  @&["<your reservation>", "<but the decision is made>", "<and you're fully committed>"]
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

echo "move:       the disagree-and-commit -- @&[\"RESERVATION\", \"THE_CALL_STANDS\", \"IM_FULLY_IN\"]"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm \
  -e '@&["I still think we are underestimating the migration risk","but the team has made the call to ship Monday","and I am fully behind making it succeed"]'
