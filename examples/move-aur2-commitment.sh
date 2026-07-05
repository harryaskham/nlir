#!/usr/bin/env bash
# nlir POWER-MOVE (aur-2) — "the scoped commitment": what I'll deliver, by when, and the honest dependency.
#
# THE MOVE (reusable):
#     @ & [ WHAT_ILL_DELIVER , BY_WHEN , THE_DEPENDENCY_OR_RISK ]
#     └ formal   └ &[...] binds the deliverable to a deadline AND its honest precondition
#
# A commitment you can actually stand behind: name the deliverable, the deadline, and the one
# dependency or risk that could move it. One line = a promise with its fine print attached, so
# nobody's surprised later.
#
# Filled example:
#   @&['i will ship the search reindexing pipeline',
#      'by end of next week',
#      'assuming the ops team frees up the staging cluster by monday']
#
# Real output (claude-sonnet-5):
#   "I will ship the search reindexing pipeline by the end of next week, assuming the operations
#    team frees up the staging cluster by Monday."
#
# REUSE IT:  @&[<what you'll deliver>, <by when>, <the dependency/risk>]
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR="@&['i will ship the search reindexing pipeline','by end of next week','assuming the ops team frees up the staging cluster by monday']"

echo "move:       the scoped commitment -- @&[deliverable, by-when, dependency/risk]"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
