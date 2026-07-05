#!/usr/bin/env bash
# nlir POWER-MOVE (aur-2) — "the decision record": state the call you're making AND the questions it
# leaves open — the honest skeleton of every real decision doc / ADR, in one line.
#
# THE MOVE (reusable):
#     [ @&[ DECISION_FACTS ] , 'OPEN_QUESTION'? , 'OPEN_QUESTION'? ]
#       └ formal composed decision      └ ? flips each unknown into a question
#     └───────────── a list: the decision, then the questions still open, one per line
#
# A COMBINATION move: the composer (@&[...]) states the decision + its driver as one polished sentence;
# the question set (postfix ?) turns your remaining unknowns into the crisp open questions. Together
# they're the shape every good decision has — what we're doing, and what we still need to resolve.
# (? is POSTFIX: the unknown goes 'before'?, not [?'before'].)
#
# Filled example:
#   [@&['migrate the primary store to postgres in Q2','driver is the json indexing we need'],
#    'the team is trained on postgres'?,
#    'we can absorb a two-hour migration window'?]
#
# Real output (claude-sonnet-5), decision then open questions:
#   "The primary data store will be migrated to PostgreSQL in the second quarter (Q2), a decision
#    driven primarily by the requirement for JSON indexing capabilities."
#   "Is the team trained on Postgres?"
#   "Can we absorb a two-hour migration window?"
#
# REUSE IT:  [@&[<decision + driver>], '<open unknown>'?, '<open unknown>'?]
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR="[@&['migrate the primary store to postgres in Q2','driver is the json indexing we need'],'the team is trained on postgres'?,'we can absorb a two-hour migration window'?]"

echo "move:       the decision record -- [@&[DECISION], 'OPEN'?, 'OPEN'?]  (line 1 = the call, then the open questions)"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
