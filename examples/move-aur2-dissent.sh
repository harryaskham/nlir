#!/usr/bin/env bash
# nlir POWER-MOVE (aur-2) — "respectful dissent": disagree on principle, constructively.
#
# THE MOVE (reusable):
#     @ & [ ! THE_PROPOSAL , MY_REASONING , WHAT_ID_SUPPORT_INSTEAD ]
#     └ formal   └ &[...] weaves a principled disagreement into one respectful message
#              └ the ! slot REJECTS the proposal — so put the POSITIVE proposal here; ! does the "no"
#
# Stronger than a partial-accept (which says yes to some, no to some): this is a full, reasoned NO
# to a proposal, softened by giving your reasoning and — crucially — a constructive alternative you
# WOULD back. Disagreement that moves the conversation forward instead of just blocking it.
#
# Filled example:
#   @&['!we should rewrite the billing system from scratch this quarter',
#      'the current one is ugly but it works and handles years of edge cases we would have to rediscover the hard way',
#      'I would support carving out the worst module and refactoring it behind the existing interface instead']
#
# Real output (claude-sonnet-5):
#   "I would advise against undertaking a complete rewrite of the billing system this quarter. While
#    the current system is inelegant, it remains functional and accounts for years of accumulated edge
#    cases that we would otherwise need to rediscover through a difficult and time-consuming process. I
#    would instead support isolating the most problematic module and refactoring it while preserving
#    the existing interface."
#
# GOTCHA (learned the hard way): the ! slot NEGATES, so give it the POSITIVE proposal
# ('!we should rewrite ...'), NOT an already-negative one ('!we should not ...') — a double negative
# flips the meaning and the model will (rightly) flag the contradiction. ! does the "no" for you.
#
# REUSE IT:  @&[!<the proposal you're rejecting>, <your reasoning>, <the alternative you'd support>]
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR="@&['!we should rewrite the billing system from scratch this quarter','the current one is ugly but it works and handles years of edge cases we would have to rediscover the hard way','I would support carving out the worst module and refactoring it behind the existing interface instead']"

echo "move:       respectful dissent -- @&[!the proposal, your reasoning, the alternative you'd support]"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
