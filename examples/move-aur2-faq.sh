#!/usr/bin/env bash
# nlir POWER-MOVE (aur-2) — "the FAQ entry": jot each question and its raw answer; get a polished,
# plain-language Q&A pair (or a whole mini-FAQ). For help docs, onboarding, support macros.
#
# THE MOVE (reusable):
#     [ 'QUESTION'? , :'RAW_ANSWER' , 'QUESTION'? , :'RAW_ANSWER' , ... ]
#        └ ? flips the statement into a question   └ : rewrites the answer in plain, warm words
#     └───────────── a list: question, answer, question, answer — one per line
#
# You have the facts ("we export it, then delete after 30 days") but need them as customer-ready Q&A.
# ? turns each unknown into the question your user actually asks; : rewrites each answer into plain
# language (no jargon). Pair them up and you get a support-ready FAQ block. Use @ for a formal answer
# (policy/legal), : for a friendly customer one.
#
# NOTE: ? is POSTFIX (goes after the question string, 'x'? not [?'x']).
#
# Filled example (two pairs):
#   ['can I use it offline'?, :'yes, changes sync when you reconnect',
#    'is my data encrypted'?, :'yes, both in transit and at rest']
#
# Real output (claude-sonnet-5), question then plain answer, per pair:
#   "Can you use it offline?"
#   "Yes, your changes will save and update once you're back online."
#   "Is my data encrypted?"
#   "Yes, your information is safe both while it's being sent and while it's being stored."
#
# REUSE IT:  ['<question>'?, :'<raw answer>', ...]   (repeat the pair; @ for a formal answer)
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR="['can I use it offline'?,:'yes, changes sync when you reconnect','is my data encrypted'?,:'yes, both in transit and at rest']"

echo "move:       the FAQ entry -- ['QUESTION'?, :'ANSWER', ...]  (question then plain answer, per pair)"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
