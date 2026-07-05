#!/usr/bin/env bash
# nlir POWER-MOVE (aur-2) — "the partial-accept counter-offer": yes to part, no to part, here's the alternative.
#
# THE MOVE (reusable — note the ! slot):
#     @ & [ ACCEPT_PART , !REJECT_PART_and_reason , YOUR_ALTERNATIVE ]
#     │   │   └ accept     └ ! REJECTS this piece    └ what to do instead
#     │   └ &[...] weaves the three into one coherent reply
#     └ @ formal (swap : plain / ~ terse)
#
# The composer's SLOTS are individually transformable — here a ! slot flips one piece to a
# rejection inside the weave, so one line says "yes to A, no to B (because…), instead C."
# A nuanced negotiation reply, not a flat yes/no.
#
# Filled example:
#   @&['accept the api redesign now',
#      '!the database migration this sprint, given the release risk',
#      'instead defer that migration to the quiet week after launch']
#
# Real output (claude-sonnet-5):
#   "We will proceed with the API redesign immediately. However, in light of the release
#    risk, the database migration will not be undertaken this sprint; it will instead be
#    deferred to the quieter week following launch."
#
# CAVEAT (documented): keep slots CONSISTENT. If a slot restates a plan that LATER slots
# contradict (e.g. ':their plan to do EVERYTHING' + '!part of it'), the composer sometimes
# FLAGS the inconsistency instead of weaving — and does so non-deterministically. So it is
# NOT a reliable consistency-checker; construct slots that agree.
#
# REUSE IT:  @&[<accept part>, !<reject part + reason>, <your alternative>]
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR="@&['accept the api redesign now','!the database migration this sprint, given the release risk','instead defer that migration to the quiet week after launch']"

echo "move:       the partial-accept counter-offer -- @&[accept, !reject+reason, alternative]"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
