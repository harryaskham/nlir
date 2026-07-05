#!/usr/bin/env bash
# nlir POWER-MOVE (aur-0) — "the cited synthesis": weave scattered asks into one crisp position.
#
# THE MOVE (reusable — learn the shape, fill the slots):
#     @ ~ ( 0^_-1 )
#     │ │     └ 0^_-1 = EVERY one of their turns (a range over the role channel; ^_ = their side)
#     │ └ ~ distils the whole scattered ask to its essence
#     └ @ formalises it into one professional requirement line
#
# nlir's real strength: read their WHOLE side of the chat — however many turns — and hand back
# "here's what you're REALLY asking for." The role knob (^ = the agent's side / ^_ = theirs, and
# it's relative to who's driving) sits alongside the tone knob. Grounding/reference lane.
# Showcase card: showcase/nlir-cited-synthesis.png
#
# Real output (copilot/claude, LIVE — this script re-runs it):
#   "The user requests that the new analytics dashboard deliver improved performance, support
#    offline functionality, and provide a simpler, less cluttered interface than the current version."
#
# REUSE IT:  @~(0^_-1)   — synthesise their WHOLE side (every turn) into one position.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT
cat > "$CTX" <<'JSON'
{"_messages":[
{"role":"user","content":"I want the new analytics dashboard to be genuinely fast, even on big accounts"},
{"role":"assistant","content":"Noted — performance is a priority."},
{"role":"user","content":"also it really needs to keep working offline, our field reps lose signal constantly"},
{"role":"assistant","content":"Understood, offline support too."},
{"role":"user","content":"and honestly the current one is way too cluttered, people can't find anything"}
]}
JSON

EXPR="@~(0^_-1)"

echo "move:       the cited synthesis -- @~(0^_-1)  (0^_-1 = every one of their turns)"
echo "chat:       three scattered asks: 'make it fast' · 'work offline' · 'it's too cluttered'"
echo "---"
"$NLIR" ${NLIR_CONFIG:+--config "$NLIR_CONFIG"} ${NLIR_MODEL:+--model "$NLIR_MODEL"} --context-file "$CTX" --mode llm -e "$EXPR"
