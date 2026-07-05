#!/usr/bin/env bash
# nlir POWER-MOVE (aur-2) — "the meeting recap": what we decided, what's still open, who does what.
#
# THE MOVE (reusable):
#     @ & [ WHAT_WE_DECIDED , WHATS_STILL_OPEN , THE_ACTION_ITEMS ]
#     └ formal   └ &[...] weaves the three parts of a clean recap into one note
#
# After any meeting or thread: capture the decision, flag what's still undecided, and list the
# action items with owners. One line = a recap people can act on, with nothing lost.
#
# Filled example:
#   @&['we decided to launch the beta to a five percent cohort on friday',
#      'still open is whether to gate it behind a feature flag or a separate url',
#      'action items: alice wires the metrics dashboard, bob writes the rollback runbook']
#
# Real output (claude-sonnet-5):
#   "We have decided to launch the beta to a five percent cohort on Friday. It remains undetermined
#    whether access will be gated behind a feature flag or provided via a separate URL. Regarding
#    action items: Alice will implement the metrics dashboard, and Bob will prepare the rollback runbook."
#
# SLOT RULE (learned the hard way): a composer slot takes PLAIN CONTENT or ONE transform (:X / !X /
# ~X). A full TRAIN in a slot (e.g. :>'a term' to auto-explain it inline) BREAKS the weave — the
# composer dropped the other slots. Keep each slot to content or a single op; explain a term in its
# own separate expression, not inside the weave.
#
# REUSE IT:  @&[<what we decided>, <what's still open>, <action items + owners>]
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR="@&['we decided to launch the beta to a five percent cohort on friday','still open is whether to gate it behind a feature flag or a separate url','action items: alice wires the metrics dashboard, bob writes the rollback runbook']"

echo "move:       the meeting recap -- @&[what we decided, what's still open, action items]"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
