#!/usr/bin/env bash
# nlir POWER-MOVE (aur-2) — "the computed brief": drop a LIVE CALCULATION into a slot and let nlir do
# the arithmetic AND phrase the result in a polished sentence. Your two lanes at once: math + prose.
#
# THE MOVE (reusable):
#     @ & [ LEAD_IN , <a live calculation> , TAIL ]
#     └ formal   └ &[...] weaves the parts, and the calc is EVALUATED first
#
# Any slot can be an arithmetic expression over quoted numbers — '1500'*'180', '47'+'12', 'a
# hundred'*('a hundred'+'one')/'two' — and nlir coerces + computes it, then folds the resulting figure
# straight into the sentence (comma-formatted, spelled where natural). No calculator, no copy-paste of
# a number you worked out separately: the figure and its framing come out together, always consistent.
#
# WHY IT WORKS: nlir's number coercion runs INSIDE the composer. A slot like '1500'*'180' becomes
# 270000 before the & weave, so the LLM realizes "...approximately 270,000 requests..." — the maths is
# deterministic, the prose is fluent. (Coercion is offline for plain/$/0x/0b/1,000/50%/1÷2 numbers.)
#
# Filled example:
#   @&['the three-minute outage dropped roughly', '1500'*'180', 'requests',
#      'before failover recovered the service']
#
# Real output (claude-sonnet-5):
#   "The three-minute outage resulted in the loss of approximately 270,000 requests before failover
#    restored service."
#
# REUSE IT:  @&[<lead-in>, <a calc over 'quoted' numbers>, <tail>]
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR="@&['the three-minute outage dropped roughly','1500'*'180','requests','before failover recovered the service']"

echo "move:       the computed brief -- @&[LEAD_IN, <a live calc>, TAIL]  (nlir does the maths, then phrases it)"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
