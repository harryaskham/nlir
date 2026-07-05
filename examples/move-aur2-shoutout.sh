#!/usr/bin/env bash
# nlir POWER-MOVE (aur-2) — "the shout-out": recognize someone's work, its impact, and say thanks.
#
# THE MOVE (reusable):
#     @ & [ WHAT_THEY_DID , THE_IMPACT , THE_THANKS ]
#     └ formal   └ &[...] weaves a genuine, specific recognition
#
# Recognition that lands: name exactly what they did, the concrete impact, and the thanks. One line
# = a shout-out worth reading, not a generic "great job".
#
# TONE-KNOB NUANCE (learned here): the leading op sets register AND reading level. For a shout-out
# with TECHNICAL content, use @ (formal — keeps "caching", "p99 latency" intact and polished). The
# : (warm/plain) op SIMPLIFIES the jargon too — it turned "caching work" into "making the computer
# remember things better", charming for a non-technical audience but dumbing down a peer shout-out.
# : = warm AND plain; @ = formal AND keeps the terms. Bare &[...] keeps terms but reads "and...and".
#
# Filled example:
#   @&['huge thanks to priya for the caching work',
#      'it cut our p99 latency in half overnight',
#      'the whole team noticed the difference this morning']
#
# Real output (claude-sonnet-5):
#   "I would like to extend my sincere appreciation to Priya for her work on the caching
#    implementation, which reduced our p99 latency by fifty percent overnight. The entire team
#    observed the improvement this morning."
#
# REUSE IT:  @&[<what they did>, <the impact>, <the thanks>]
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR="@&['huge thanks to priya for the caching work','it cut our p99 latency in half overnight','the whole team noticed the difference this morning']"

echo "move:       the shout-out -- @&[what they did, the impact, the thanks]  (@ keeps it polished; : would dumb the jargon)"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
