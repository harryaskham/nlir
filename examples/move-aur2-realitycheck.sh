#!/usr/bin/env bash
# nlir POWER-MOVE (aur-2) — "the reality-check": pose a pointed question that carries a LIVE computed
# figure. nlir does the arithmetic AND frames it as the question to answer — pressure-test a plan,
# a capacity, a budget with the ACTUAL number.
#
# THE MOVE (reusable):
#     @ & [ 'LEAD_IN' , <a live calc> , 'CLOSING_CLAUSE'? ]
#     └ formal   └ &[...] weaves    └ the calc is evaluated   └ the ? turns the weave into a question
#
# Two of my mechanisms in one: the calc slot (like the computed brief) is EVALUATED and folded in
# (comma/currency formatted), and the trailing `?` (like the question set) turns the whole woven
# statement into a question. So instead of "we'd spend 12 * 2500 a month, is that ok?" you get one
# clean, number-carrying question you can drop straight into a planning thread.
#
# Filled example:
#   @&['does', '12'*'2500', 'dollars a month fit our infra budget'?]
#
# Real output (claude-sonnet-5):
#   "Does an expenditure of $30,000 per month align with our infrastructure budget?"
#
# (Also works for capacity: @&['is', '1500'*'180', 'requests in one outage too much for one server'?]
#  -> a question carrying the woven 270,000.)
#
# REUSE IT:  @&['<lead-in>', <a calc over 'quoted' numbers>, '<closing clause>'?]
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR="@&['does','12'*'2500','dollars a month fit our infra budget'?]"

echo "move:       the reality-check -- @&['LEAD', <a live calc>, 'CLAUSE'?]  (does the maths AND asks the question)"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
