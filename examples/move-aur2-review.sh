#!/usr/bin/env bash
# nlir POWER-MOVE (aur-2) — "the review verdict": praise, the gap, the fix, the call — one line.
#
# THE MOVE (reusable):
#     @ & [ WHATS_GOOD , THE_ONE_GAP , THE_SPECIFIC_FIX , THE_VERDICT ]
#     └ formal   └ &[...] composes four review beats into one clean verdict
#
# Reviewing an agent's (or teammate's) work: lead with what's solid, name the one gap PLAINLY, give
# the specific fix, and state the call (approve-after-this / request-changes). One line, and it reads
# like a considered code review.
#
# IMPORTANT — flag a gap PLAINLY, do NOT ! it. `!'the missing X'` negates the whole clause to
# "X is NOT missing", which then contradicts your fix slot and trips the composer's (non-deterministic)
# inconsistency flag. `!` is for REJECTING a claim/proposal (see partial-accept), not for naming a gap.
#
# Filled example:
#   @&['the caching layer design is solid and well-scoped',
#      'the one gap is that cache invalidation is missing on user updates',
#      'add an invalidation hook on the user-update path',
#      'approve once that hook is in']
#
# Real output (claude-sonnet-5):
#   "The caching layer design is solid and well-scoped. The one gap is that cache invalidation is
#    missing on user updates. Please add an invalidation hook on the user-update path; approval will
#    follow once that hook is in place."
#
# REUSE IT:  @&[<what's good>, <the one gap>, <the specific fix>, <the verdict>]
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR="@&['the caching layer design is solid and well-scoped','the one gap is that cache invalidation is missing on user updates','add an invalidation hook on the user-update path','approve once that hook is in']"

echo "move:       the review verdict -- @&[what's good, the gap, the fix, the verdict]"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
