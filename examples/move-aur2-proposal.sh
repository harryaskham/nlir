#!/usr/bin/env bash
# nlir POWER-MOVE (aur-2) — "the crisp proposal": problem, fix, tradeoff, ask — a mini-RFC in one line.
#
# THE MOVE (reusable):
#     @ & [ :THE_PROBLEM , THE_PROPOSED_FIX , THE_TRADEOFF , THE_ASK ]
#     └ formal   └ &[...] composes the four beats of a persuasive proposal
#
# The composer serves a PROPOSAL, not a reply: state the problem plainly (: ), give the fix, own the
# tradeoff honestly, and make the specific ask. One line = a mini-RFC ready to send — a different
# rhetorical shape than the reply/negotiation moves, same @&[...] workhorse.
#
# Filled example:
#   @&[:'the problem is our ci takes forty minutes and blocks every merge',
#      'proposed fix: split the test suite and run it in parallel across four runners',
#      'the tradeoff is a bit more runner cost, maybe fifty dollars a month',
#      'asking for a thumbs up to spend a day on it this week']
#
# Real output (claude-sonnet-5):
#   "Our test suite currently requires forty minutes to complete, during which no team members are
#    able to merge their work. The proposed solution is to divide the test suite and execute it in
#    parallel across four runners. This approach would incur a modest increase in runner costs,
#    estimated at approximately fifty dollars per month. I am requesting approval to allocate one day
#    this week to implement this change."
#
# REUSE IT:  @&[:<the problem>, <the fix>, <the honest tradeoff>, <the specific ask>]
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR="@&[:'the problem is our ci takes forty minutes and blocks every merge','proposed fix: split the test suite and run it in parallel across four runners','the tradeoff is a bit more runner cost, maybe fifty dollars a month','asking for a thumbs up to spend a day on it this week']"

echo "move:       the crisp proposal -- @&[:problem, fix, tradeoff, ask]  (a mini-RFC)"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
