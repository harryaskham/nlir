#!/usr/bin/env bash
# nlir POWER-MOVE (aur-2) — "the pre-mortem": a plan + its most likely failure + the hedge, woven
# into one clear-eyed heads-up. Forward-looking risk planning (vs the retro, which looks back).
#
# THE MOVE (reusable):
#     @ & [ "THE_PLAN" , !"THE_ROSY_CLAIM" , "THE_HEDGE" ]
#       @&[…] = formalize + weave     !"…" = REJECT the optimistic claim → surfaces the failure mode
#     └──────── plan, then the risk it hides, then how you've hedged it — one statement
#
# The `!` slot is the trick: you write the ROSY claim you DON'T fully believe ("the migration will be
# seamless") and `!` flips it into the honest risk. So a pre-mortem writes itself: state the plan,
# name the thing that could go wrong, show the hedge. @&[…] braids all three into one calm heads-up.
#
# Filled example:
#   @&["we ship the new billing system Monday", !"the data migration will be seamless",
#      "we keep the old system on standby for 48h"]
#
# Real output (claude-sonnet-5):
#   "The new billing system will be deployed on Monday. Please be advised that the data migration
#    process is not expected to proceed seamlessly. Accordingly, the legacy system will remain on
#    standby for 48 hours as a precautionary measure."
#
# REUSE IT:  @&["<the plan>", !"<the thing you're quietly worried won't hold>", "<your hedge>"]
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

echo "move:       the pre-mortem -- @&[\"PLAN\", !\"ROSY_CLAIM\", \"HEDGE\"]  (plan + the risk it hides + the hedge)"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm \
  -e '@&["we ship the new billing system Monday",!"the data migration will be seamless","we keep the old system on standby for 48h"]'
