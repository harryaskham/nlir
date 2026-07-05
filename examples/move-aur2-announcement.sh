#!/usr/bin/env bash
# nlir POWER-MOVE (aur-2) — "the change announcement": tell people what's changing and what to do.
#
# THE MOVE (reusable):
#     @ & [ WHATS_CHANGING , EFFECTIVE_WHEN , WHAT_YOU_NEED_TO_DO ]
#     └ formal   └ &[...] weaves a clean change announcement into one message
#
# For a deprecation, policy shift, migration, or process change: state what's changing, when it takes
# effect, and the ONE action the reader needs to take. Forward-looking (unlike the meeting recap,
# which looks back at a decision) and it always ends with a clear ask so nobody is left guessing.
#
# Filled example:
#   @&['starting next monday we are moving all deploys to the new CI pipeline',
#      'the old jenkins jobs will be switched off at the end of the month',
#      'please migrate your service configs to the new format and ping the platform team if anything breaks']
#
# Real output (claude-sonnet-5):
#   "Effective next Monday, all deployments will transition to the new CI pipeline. The existing
#    Jenkins jobs will be decommissioned at the end of the month. Please migrate your service
#    configurations to the new format accordingly, and notify the Platform Team promptly should any
#    issues arise."
#
# WHY IT WORKS: the three slots answer the three questions every announcement must — what, when, and
# "what do I do?". Ending on the action turns an FYI into something people can act on.
#
# REUSE IT:  @&[<what's changing>, <when it takes effect>, <what the reader needs to do>]
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR="@&['starting next monday we are moving all deploys to the new CI pipeline','the old jenkins jobs will be switched off at the end of the month','please migrate your service configs to the new format and ping the platform team if anything breaks']"

echo "move:       the change announcement -- @&[what's changing, effective when, what you need to do]"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
