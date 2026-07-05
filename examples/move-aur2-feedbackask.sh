#!/usr/bin/env bash
# nlir POWER-MOVE (aur-2) — "the feedback ask": request TARGETED review, not a vague "thoughts?".
#
# THE MOVE (reusable):
#     @ & [ WHAT_I_MADE_+_WHERE , THE_SPECIFIC_THING_TO_CHECK , BY_WHEN ]
#     └ formal   └ &[...] weaves a good review request into one message
#
# The natural counterpart to the review-verdict (which GIVES a review). A good feedback ask points
# the reviewer at the exact part you're unsure about (so they spend their attention where it counts)
# and states the deadline. "Please review X, especially Y, by Z" — never a vague "any thoughts?".
#
# Filled example:
#   @&['I have pushed the draft onboarding flow to the staging branch',
#      'could you specifically sanity-check the error-handling paths and the mobile layout — those are the parts I am least sure about',
#      'I would love your thoughts before the design review on thursday']
#
# Real output (claude-sonnet-5):
#   "I have pushed the draft onboarding flow to the staging branch. Could you please review it, with
#    particular attention to the error-handling paths and the mobile layout, as these are the areas
#    about which I am least confident? I would greatly appreciate your feedback prior to Thursday's
#    design review."
#
# WHY IT WORKS: the middle slot is the whole trick — naming the SPECIFIC thing you want checked (and
# admitting where you're unsure) turns a request people skim into one they can actually action fast.
#
# REUSE IT:  @&[<what I made + where>, <the specific thing to check>, <by when>]
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR="@&['I have pushed the draft onboarding flow to the staging branch','could you specifically sanity-check the error-handling paths and the mobile layout — those are the parts I am least sure about','I would love your thoughts before the design review on thursday']"

echo "move:       the feedback ask -- @&[what I made + where, the specific thing to check, by when]"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
