#!/usr/bin/env bash
# nlir POWER-MOVE (aur-2) — "the clarifying reframe": confirm you understood before you act.
#
# THE MOVE (reusable):
#     [ : CONCRETE_RESTATEMENT_OF_THEIR_ASK , 'IS_THAT_RIGHT' ? ]
#       └ : restates their (often jargon-y / vague) ask in PLAIN terms
#                                              └ postfix ? turns your check into a real question
#
# Before you build the wrong thing: play the request back in plain, concrete terms, then ask if you
# got it right. Two top-level list elements, realised separately — a plain restatement, then a
# confirmation question. If you can say it plainly and they agree, you're aligned.
#
# Filled example:
#   [:'so what you need is a weekly summary email of the top three support issues, sent every friday morning to the leadership list',
#     'have I got that right'?]
#
# Real output (claude-sonnet-5):
#   "Every Friday morning, send an email to the leaders that shows the three biggest problems
#    customers had that week.
#    Did I get that right?"
#
# WHY IT WORKS: the : does the work — it strips the jargon so the restatement is in words anyone can
# check, and the ? makes it an actual question rather than a silent assumption. Restating plainly is
# the fastest way to surface a misunderstanding before it costs you a sprint.
#
# REUSE IT:  [:'<their ask, restated concretely>', '<your confirmation question>'?]
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR="[:'so what you need is a weekly summary email of the top three support issues, sent every friday morning to the leadership list','have I got that right'?]"

echo "move:       the clarifying reframe -- [:restate their ask plainly, 'is that right'?]"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
