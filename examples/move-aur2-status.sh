#!/usr/bin/env bash
# nlir POWER-MOVE (aur-2) — "the terse status ping": done / blocked / next, in one crisp line.
#
# THE MOVE (reusable — the ~ leading op = TERSE tone):
#     ~ & [ WHATS_DONE , WHATS_BLOCKED , WHATS_NEXT ]
#     └ ~ = TERSE register (a one-liner). Swap @ for a formal multi-sentence status.
#
# The three beats of a standup — done, blocked, next — woven into one line. Completes the TONE
# KNOB trio: @ formal · : warm · ~ TERSE. Same slots, three registers.
#
# Filled example:
#   ~&['finished the auth service migration',
#      'blocked on the staging database credentials',
#      'starting the rate-limiter next']
#
# Real output — ~ (TERSE, claude-sonnet-5):
#   "Finished the auth service migration and will start the rate-limiter next, but is blocked on
#    staging database credentials."
#
# Real output — @ (FORMAL, SAME slots):
#   "The authentication service migration has been completed. Progress is currently blocked pending
#    receipt of the staging database credentials. Work on the rate limiter will commence next."
#
# REUSE IT:  ~&[<done>, <blocked>, <next>]   (swap ~ -> @ for a formal status)
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR="~&['finished the auth service migration','blocked on the staging database credentials','starting the rate-limiter next']"

echo "move:       the terse status ping -- ~&[done, blocked, next]  (~ terse; swap @ for formal)"
echo "--- terse (~) execution:"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
