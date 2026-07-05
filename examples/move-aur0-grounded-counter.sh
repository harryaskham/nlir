#!/usr/bin/env bash
# nlir POWER-MOVE (aur-0) — "the grounded counter": reply + amend + reference a prior constraint, formal.
#
# THE MOVE (reusable — learn the shape, fill the slots):
#     @ ( ^-1  &  '<your amendment>'  &  ^_-1 )
#     │    │            │                  └ ^_-1 = your earlier point — GROUNDS the reply in prior context
#     │    │            └ your modification to their idea
#     │    └ ^-1 = the agent's last suggestion (reads live chat)
#     └ @ formalises the whole weave as ONE coherent reply
#
# nlir's real strength: a few sigils carry a COMPLEX real intent. This ONE expression =
# "reply to their suggestion, fold in my change, and remind them of an earlier constraint
# — professionally." The 3-move cousin of aur-1's considered-reply, adding the `& ^_-1`
# cross-reference. Showcase card: showcase/nlir-grounded-counter.png
#
# Real output (copilot/claude, LIVE — this script re-runs it):
#   "I recommend caching the complete user graph in Redis to address the API latency issue,
#    scoped specifically to the hottest 10% of users. Please note that our infrastructure
#    budget is frozen for this quarter."
#
# REUSE IT:  @(^-1 & '<your change>' & ^_-N)   — reply, amend, and cite an earlier point.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT
cat > "$CTX" <<'JSON'
{"_messages":[
{"role":"user","content":"our infra budget is frozen this quarter"},
{"role":"assistant","content":"I suggest we cache the entire user graph in Redis to fix the API latency"}
]}
JSON

EXPR="@(^-1 & '- but scoped to just the hot 10% of users' & ^_-1)"

echo "move:       the grounded counter -- @(^-1 & amendment & ^_-1)"
echo "chat:       you: 'infra budget is frozen'  ·  agent: 'cache the whole user graph in Redis'"
echo "---"
"$NLIR" ${NLIR_CONFIG:+--config "$NLIR_CONFIG"} ${NLIR_MODEL:+--model "$NLIR_MODEL"} --context-file "$CTX" --mode llm -e "$EXPR"
