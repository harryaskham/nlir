#!/usr/bin/env bash
# nlir POWER-MOVE (aur-2) — "the dual-register brief": announce the SAME facts to two audiences at
# once — your engineers AND your non-technical stakeholders — in one keystroke-set.
#
# THE MOVE (reusable):
#     [ @&[ FACTS ] , :&[ SAME_FACTS ] ]
#       └ formal, keeps jargon   └ warm, PLAIN (dumbs the jargon)
#     └───────────── a 2-element list: two renderings of the same content
#
# One announcement, two registers. The FIRST slot (@&[...]) is the peer / engineering version — it
# keeps the technical terms polished. The SECOND (:&[...]) is the stakeholder / customer version —
# the : tone rewrites the jargon into plain words. Same facts; nlir prints BOTH, one per line.
#
# WHY IT WORKS (my core tone finding): the leading op is a READING-LEVEL dial, not just a register.
#   @ = formal, KEEPS the terms ("p99 read latency", "cache warm-up").
#   : = warm, SIMPLIFIES the terms ("a notebook it can check", "a few minutes to fill up").
# Wrapping the same &[FACTS] in each gives you the technical brief and the plain brief together —
# no second write-up, no drift between the two versions.
#
# Filled example (FACTS repeated in each slot):
#   [@&['roll out the new caching layer','cuts p99 read latency by 60%',
#       'needs a brief cache warm-up after deploy'],
#    :&['roll out the new caching layer','cuts p99 read latency by 60%',
#       'needs a brief cache warm-up after deploy']]
#
# Real output (claude-sonnet-5), two lines:
#   [engineers] "Deployment of the new caching layer reduces p99 read latency by 60% and requires a
#               brief cache warm-up period following release."
#   [everyone]  "We're turning on a new helper that remembers things for the computer, kind of like a
#               notebook it can check instead of searching everywhere. This makes it answer much
#               faster — about 60% faster — almost every single time. Right after we turn it on,
#               though, it needs a few minutes to fill up its notebook before it works at its best."
#
# REUSE IT:  [@&[<facts>], :&[<same facts>]]   (swap @/: for any two of the three tones @ · : · ~)
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

FACTS="'roll out the new caching layer','cuts p99 read latency by 60%','needs a brief cache warm-up after deploy'"
EXPR="[@&[$FACTS],:&[$FACTS]]"

echo "move:       the dual-register brief -- [@&[FACTS], :&[SAME_FACTS]]  (line 1 = engineers, line 2 = everyone)"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
