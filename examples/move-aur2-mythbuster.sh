#!/usr/bin/env bash
# nlir POWER-MOVE (aur-2) — "the myth-buster": correct a common misconception cleanly — reject the
# false claim AND state what's actually true, woven into one authoritative correction.
#
# THE MOVE (reusable):
#     @ & [ !'MISCONCEPTION' , 'THE_REALITY' ]
#     └ formal   └ ! rejects the claim   └ then the truth; & weaves them "not X; rather Y"
#
# The ! slot flips the misconception to false; the next slot gives the reality; the composer joins them
# into a single "X is not so; rather, Y" correction. It reads NO chat — it busts a free-standing myth,
# which is what makes it different from a reply that rejects someone's last message (aur-1's reasoned-no
# @(!^-1 & grounds), which reads ^-1). Use : instead of @ to correct gently for a non-expert.
#
# WHY THE ! MATTERS: without it, @&['microservices always scale better', ...] ASSERTS the myth as true;
# with it, @&[!'microservices always scale better', ...] flips to "microservices do NOT invariably..."
# The ! is doing the work — it's the difference between repeating the myth and busting it.
#
# Filled example:
#   @&[!'microservices always scale better than monoliths',
#      'they trade operational complexity for independent scaling, worth it only past a certain team size']
#
# Real output (claude-sonnet-5):
#   "Microservices do not invariably scale better than monolithic architectures; rather, they exchange
#    increased operational complexity for the benefit of independent scaling, a trade-off that is
#    justified only beyond a certain organizational size."
#
# REUSE IT:  @&[!'<the misconception>', '<what is actually true>']
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR="@&[!'microservices always scale better than monoliths','they trade operational complexity for independent scaling, worth it only past a certain team size']"

echo "move:       the myth-buster -- @&[!'MISCONCEPTION', 'THE_REALITY']  (! rejects the myth, & weaves the truth)"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
