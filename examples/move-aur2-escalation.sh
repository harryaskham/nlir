#!/usr/bin/env bash
# nlir POWER-MOVE (aur-2) — "the escalation": raise a blocker upward, well.
#
# THE MOVE (reusable):
#     @ & [ THE_BLOCKER , THE_IMPACT , ~ WHAT_YOU_TRIED , THE_SPECIFIC_ASK ]
#     └ formal   └ &[...] weaves the four parts of a good escalation into one message
#                                └ the ~ slot DIGESTS a long "here's everything I tried" into one crisp clause
#
# A good escalation isn't a complaint — it's a decision request. State the blocker, the impact
# (why it matters now), a DIGEST of what you've already exhausted (so it's clear you're not just
# passing the problem up), and the ONE specific thing you need the reader to decide or do.
#
# Filled example:
#   @&['I am blocked on the vendor API — their sandbox has returned 500s for two days',
#      'this is holding the payments integration and will slip our launch',
#      '~I have retried with fresh credentials, tested from three networks, and opened two support tickets with no reply',
#      'I need you to escalate through our account manager or approve switching to the backup provider']
#
# Real output (claude-sonnet-5):
#   "I am currently blocked by an issue with the vendor API. Their sandbox environment has been
#    returning HTTP 500 errors for the past two days, which is delaying the payments integration and
#    places our launch timeline at risk. To date, I have attempted to resolve the issue by retrying
#    with new credentials, testing from three separate networks, and submitting two support tickets,
#    none of which have received a response. I would appreciate it if you could escalate this matter
#    through our account manager, or alternatively, approve a switch to the backup provider."
#
# WHY THE ~ SLOT: the "what you tried" list is usually long and defensive. Prefixing that slot with
# ~ (digest) folds it into one tight clause — "To date, I have attempted ... none of which received a
# response" — so the escalation stays short and reads as competent, not as a rant.
#
# REUSE IT:  @&[<the blocker>, <the impact>, ~<everything you tried>, <the one specific ask>]
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR="@&['I am blocked on the vendor API — their sandbox has returned 500s for two days','this is holding the payments integration and will slip our launch','~I have retried with fresh credentials, tested from three networks, and opened two support tickets with no reply','I need you to escalate through our account manager or approve switching to the backup provider']"

echo "move:       the escalation -- @&[blocker, impact, ~what you tried, the specific ask]"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
