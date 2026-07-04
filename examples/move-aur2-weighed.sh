#!/usr/bin/env bash
# nlir POWER-MOVE (aur-2) — "the weighed recommendation": two options + your verdict, one line.
#
# THE MOVE (reusable):
#     @ & [ :OPTION_A , :OPTION_B , YOUR_VERDICT ]
#     │   │   └ each option : simplified to a plain summary; then your call
#     │   └ &[...] weaves the pieces into one coherent statement (the COMPOSER)
#     └ @ sets register (swap : plain / ~ terse)
#
# The SAME composer as the counter-reply (@&[...]) -- proof the pattern GENERALISES: &[...]
# weaves any set of points into one coherent text, the leading op (@/:/~) sets register, and
# each slot is transformable (: plain, ! reject, ~ gist). Fill it for a different INTENT and
# you get a different document. Here: lay out two options plainly + state your recommendation
# -> a professional options memo.
#
# Filled example:
#   @&[:'option one: keep the monolith and add a caching layer',
#      :'option two: split into microservices now',
#      'recommend option one for this quarter and revisit microservices after the release']
#
# Real output (claude-sonnet-5):
#   "Two options are under consideration: the first involves retaining the current
#    architecture while incorporating a caching mechanism ...; and the second involves
#    decomposing the monolithic application ... We recommend proceeding with the first
#    option for this quarter and revisiting the microservices approach after the release ..."
#
# CAVEAT (documented): >&[...] (expand-the-weave) OVERSHOOTS into a full spec-wall -- use
# @&[...] or bare &[...] for right-sized prose; reach for > only when you WANT the essay.
#
# REUSE IT:  @&[:<option A>, :<option B>, <your verdict + why>]
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR="@&[:'option one: keep the monolith and add a caching layer',:'option two: split into microservices now','recommend option one for this quarter and revisit microservices after the release when we have more hands']"

echo "move:       the weighed recommendation -- @&[:option A, :option B, your verdict]"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
