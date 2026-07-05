#!/usr/bin/env bash
# nlir POWER-MOVE (aur-2) — "the question set": turn your nagging assumptions into the pointed
# questions you need answered BEFORE you commit. Jot each unknown as a statement; ? flips it to a
# question. A ready-to-send due-diligence / kickoff / code-review checklist.
#
# THE MOVE (reusable):
#     [ 'ASSUMPTION_1'? , 'ASSUMPTION_2'? , 'ASSUMPTION_3'? ]
#          └ ? is POSTFIX — it turns the statement before it into a crisp question
#     └───────────── a list: one question per line
#
# You think in assumptions ("the timeline is fixed", "the budget covers a rewrite"); the people you
# need answers from think in questions. ? does the flip: nlir rewrites each statement as the well-formed
# question that tests it. Lead with @ to formalize each ( @['x'?, 'y'?] ), : to keep them plain.
#
# NOTE ON SYNTAX: ? is POSTFIX, so it goes AFTER each string inside the list ('x'?), not before it
# ([?'x'] is a parse error — "? not valid in prefix position").
#
# Filled example:
#   ['the timeline is fixed'?, 'the budget covers a full rewrite'?, 'the team has the bandwidth'?]
#
# Real output (claude-sonnet-5), one question per line:
#   "Is the timeline fixed?"
#   "Does the budget cover a full rewrite?"
#   "Does the team have the bandwidth?"
#
# REUSE IT:  ['<assumption>'?, '<assumption>'?, ...]   (prefix @ to formalize each question)
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR="['the timeline is fixed'?,'the budget covers a full rewrite'?,'the team has the bandwidth'?]"

echo "move:       the question set -- ['ASSUMPTION'?, ...]  (? flips each statement into the question to ask)"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
