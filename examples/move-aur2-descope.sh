#!/usr/bin/env bash
# nlir POWER-MOVE (aur-2) — "the descope proposal": negotiate scope down to hit a deadline.
#
# THE MOVE (reusable):
#     @ & [ THE_SQUEEZE , WHAT_TO_CUT , WHAT_TO_PROTECT , THE_PAYOFF ]
#     └ formal   └ &[...] weaves a scope-cut proposal into one persuasive message
#
# When you can't ship everything on time, this frames the cut as a plan, not a failure: name the
# squeeze (why all of it won't fit), what you'd defer, what you'd protect (and why), and the payoff
# (a solid on-time launch). Distinct from a commitment (a promise) or a mini-RFC (a fix for a
# problem) — this is the deliberate trade of scope for a date, argued well.
#
# Filled example:
#   @&['we cannot ship all six features by the March deadline without burning out the team',
#      'I propose we cut the analytics dashboard and the export tool to a fast-follow',
#      'and protect the core checkout flow and the mobile fixes, which is what most users actually asked for',
#      'that gets us a solid, tested launch on time with the rest landing two weeks later']
#
# Real output (claude-sonnet-5):
#   "Delivering all six features by the March deadline is not feasible without placing undue strain
#    on the team. I recommend deferring the analytics dashboard and the export tool to a fast-follow
#    release, while prioritizing the core checkout flow and the mobile fixes—the features most
#    frequently requested by users. This approach would allow us to deliver a stable, thoroughly
#    tested launch on schedule, with the remaining features following two weeks later."
#
# WHY IT WORKS: the protect slot (with its reason) is what makes a cut land — you're not dropping
# work, you're defending the highest-value work and giving the rest a real home (the fast-follow).
#
# REUSE IT:  @&[<why it all won't fit>, <what you'd defer>, <what you'd protect + why>, <the payoff>]
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR="@&['we cannot ship all six features by the March deadline without burning out the team','I propose we cut the analytics dashboard and the export tool to a fast-follow','and protect the core checkout flow and the mobile fixes, which is what most users actually asked for','that gets us a solid, tested launch on time with the rest landing two weeks later']"

echo "move:       the descope proposal -- @&[the squeeze, what to cut, what to protect, the payoff]"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
