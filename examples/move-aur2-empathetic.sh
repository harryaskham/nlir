#!/usr/bin/env bash
# nlir POWER-MOVE (aur-2) — "the empathetic redirect": validate, agree, reframe, fix — and DIAL THE TONE.
#
# THE MOVE (reusable — the LEADING OP is a TONE KNOB):
#     : & [ VALIDATE_THE_FEELING , AGREE_THE_PAIN , REFRAME_THE_ROOT_CAUSE , THE_CONCRETE_FIX ]
#     │  └ &[...] weaves the four beats of a de-escalation into one message
#     └ : = WARM / plain tone (for empathy). Swap to @ for a FORMAL announcement — SAME slots, different tone.
#
# One expression = the classic redirect: hear them, validate, reframe the real cause, give the fix.
# The point of the composer: the LEADING OP dials register WITHOUT touching the content — : reads
# warm and human (right for empathy); @ reads formal and official (right for a policy note).
#
# Filled example:
#   :&['acknowledge the team is frustrated the deploy keeps breaking',
#      'they are right that the current process is painful',
#      'but the real root cause is skipped tests, not the tooling',
#      'so from friday every merge runs the test suite first']
#
# Real output — : (WARM, claude-sonnet-5):
#   "The team is upset because the program keeps breaking when it comes out, and they're right to
#    feel that way — it's been really annoying. But the real reason it breaks isn't the tools. It's
#    that tests have been skipped. So starting Friday, every change will be tested first before it's added."
#
# Real output — @ (FORMAL, SAME slots):
#   "We recognize the team's frustration with the recurring deployment failures, and that frustration
#    is warranted—the current process has indeed been painful. However, the root cause lies in skipped
#    tests rather than in the tooling itself. Accordingly, beginning Friday, the test suite will be run
#    on every merge before it can proceed."
#
# REUSE IT:  :&[<validate>, <agree the pain>, <reframe root cause>, <the fix>]   (swap : -> @ for a formal notice)
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR=":&['acknowledge the team is frustrated the deploy keeps breaking','they are right that the current process is painful','but the real root cause is skipped tests, not the tooling','so from friday every merge runs the test suite first']"

echo "move:       the empathetic redirect -- :&[validate, agree-pain, reframe, fix]  (: warm; swap @ for formal)"
echo "--- warm (:) execution:"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
