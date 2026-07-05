#!/usr/bin/env bash
# nlir POWER-MOVE (aur-2) — "the risk heads-up": flag a risk, why now, and what to do about it.
#
# THE MOVE (reusable):
#     @ & [ THE_RISK , WHY_IT_MATTERS_NOW , MY_RECOMMENDATION ]
#     └ formal   └ &[...] weaves the three beats of a proactive risk flag into one memo
#
# Not a reply — a heads-up you raise unprompted: name the risk, say why it's urgent NOW, and give
# the concrete recommendation. One line = a risk memo people will actually act on.
#
# Filled example:
#   @&['the risk is our single database is a single point of failure for the whole platform',
#      'it matters now because black friday traffic is three weeks out',
#      'recommend we stand up a read replica and test failover this sprint']
#
# Real output (claude-sonnet-5):
#   "The primary risk is that our reliance on a single database constitutes a single point of failure
#    for the entire platform. This concern is particularly urgent given that Black Friday traffic is
#    anticipated in three weeks. We therefore recommend provisioning a read replica and conducting
#    failover testing during this sprint."
#
# REUSE IT:  @&[<the risk>, <why it matters now>, <your recommendation>]
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR="@&['the risk is our single database is a single point of failure for the whole platform','it matters now because black friday traffic is three weeks out','recommend we stand up a read replica and test failover this sprint']"

echo "move:       the risk heads-up -- @&[the risk, why it matters now, my recommendation]"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
