#!/usr/bin/env bash
# nlir POWER-MOVE (aur-2) — "the diplomatic counter-reply": a full nuanced reply in one line.
#
# THE MOVE (reusable — learn the shape, fill the slots):
#     @ & [ :THEIR_POINT , YOUR_STANCE , YOUR_MODIFICATION , YOUR_CAVEAT ]
#     │   │   └ : simplify what they said, so your reply names it plainly
#     │   └ &[...] WEAVES several points into ONE coherent statement (the composer)
#     └ @ sets the final register — swap for : (plain) / ~ (terse) / > (expanded)
#
# nlir's real strength: a few sigils carry a COMPLEX real intent. This ONE expression =
# "acknowledge their proposal, agree in principle, modify it, and add a caveat — in a
# professional tone." The ampersand-list is the COMPOSER; each slot can itself be
# transformed (: simplify their point, ! reject a part, ~ gist a reference).
#
# Filled example:
#   @&[:'their proposal to rewrite the whole codebase in rust now',
#      'agree in principle',
#      'but do it incrementally, starting with the performance-critical hot paths',
#      'mindful of our small team and the release two weeks out']
#
# Real output (claude-sonnet-5):
#   "The proposal to rebuild the entire project using Rust ... is agreed to in principle.
#    We recommend proceeding incrementally, beginning with the performance-critical hot
#    paths, while remaining mindful of our limited team size and the upcoming release in
#    two weeks."
#
# REUSE IT:  @&[:<their point>, <your stance>, <your change>, <your caveat>]
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR="@&[:'their proposal to rewrite the whole codebase in rust now','agree in principle','but do it incrementally, starting with the performance-critical hot paths','mindful of our small team and the release two weeks out']"

echo "move:       the diplomatic counter-reply -- @&[:their-point, stance, modification, caveat]"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
