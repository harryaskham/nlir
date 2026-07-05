#!/usr/bin/env bash
# nlir POWER-MOVE (aur-2) — "the BLUF" (bottom line up front): lead with a one-sentence headline your
# reader can skim, then give the full detail underneath. The classic email/report pattern.
#
# THE MOVE (reusable):
#     [ ~&[ FACTS ] , @&[ SAME_FACTS ] ]
#       └ distil to a headline   └ the full formal version
#     └───────────── a 2-element list: the skim line, then the whole thing
#
# The FIRST slot (~&[...]) squeezes the facts into a single bottom-line sentence — what a busy reader
# gets in three seconds. The SECOND (@&[...]) is the complete, formal write-up for anyone who reads on.
# Same facts; nlir prints the headline first, then the body.
#
# SIBLING MOVE — the axis it turns: dual-register brief ([@&[X], :&[X]]) splits by WHO reads (engineers
# vs everyone); BLUF splits by HOW MUCH they read (skim vs full). Same list mechanism, different knob:
#   ~& = the distilled headline · @& = the full formal body · (: for a plain body, ~ for a terser one)
#
# Filled example (FACTS repeated in each slot):
#   [~&['the friday deploy is postponed to monday','a payments bug slipped through staging',
#       'fix is in review, needs a fresh soak test'],
#    @&['the friday deploy is postponed to monday','a payments bug slipped through staging',
#       'fix is in review, needs a fresh soak test']]
#
# Real output (claude-sonnet-5), two lines:
#   [headline] "The Friday deploy is now Monday, and a payments bug found in staging has a fix under
#              review pending a fresh soak test."
#   [full]     "The Friday deployment has been postponed to Monday. Additionally, a payments-related bug
#              was not caught during staging testing; a fix is currently under review and will require a
#              fresh soak test prior to release."
#
# REUSE IT:  [~&[<facts>], @&[<same facts>]]
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

FACTS="'the friday deploy is postponed to monday','a payments bug slipped through staging','fix is in review, needs a fresh soak test'"
EXPR="[~&[$FACTS],@&[$FACTS]]"

echo "move:       the BLUF -- [~&[FACTS], @&[SAME_FACTS]]  (line 1 = skimmable headline, line 2 = full detail)"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
