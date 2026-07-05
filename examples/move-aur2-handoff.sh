#!/usr/bin/env bash
# nlir POWER-MOVE (aur-2) — "the briefed handoff": delegate a task with the GIST of a reference folded in.
#
# THE MOVE (reusable — the ~ SLOT folds a long reference to its gist):
#     @ & [ THE_TASK , ~LONG_REFERENCE , THE_PRIORITY ]
#     │   │   │        └ ~ CONDENSES a pasted thread/doc to its gist, inside the weave
#     │   │   └ what to hand off
#     │   └ &[...] weaves task + condensed context + priority into one brief
#     └ @ formal
#
# A delegation brief in one line: name the task, fold in the GIST of a long incident thread or
# doc (the ~ slot digests it so you don't paste the whole wall), and set the priority. Shows the
# THIRD slot-transform: after : (plain a point) and ! (reject a part), ~ DIGESTS a reference.
#
# Filled example:
#   @&['take over the checkout latency investigation',
#      '~the incident thread: users report 3-5s delays at payment, started after tuesday deploy,
#        p50 latency doubled, likely the new fraud-check call is synchronous and blocking',
#      'treat it as p1 and aim for a root cause by end of week']
#
# Real output (claude-sonnet-5):
#   "Please assume ownership of the checkout latency investigation … Users are reporting payment
#    delays of three to five seconds, which began following Tuesday's deployment, with p50 latency
#    having doubled. The likely cause is that the new fraud-check call is synchronous and is blocking
#    the request. This matter should be classified as P1, with the objective of determining the root
#    cause by the end of the week."
#
# REUSE IT:  @&[<the task>, ~<paste the long context>, <the priority/deadline>]
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR="@&['take over the checkout latency investigation','~the incident thread: users report three to five second delays at payment, started after tuesday deploy, p50 latency doubled, likely the new fraud-check call is synchronous and blocking the request','treat it as p1 and aim for a root cause by end of week']"

echo "move:       the briefed handoff -- @&[task, ~long-reference-gist, priority]"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
