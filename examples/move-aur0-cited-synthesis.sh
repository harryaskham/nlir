#!/usr/bin/env bash
# nlir POWER-MOVE (aur-0) — "the cited synthesis": weave scattered asks into one crisp position.
#
# THE MOVE (reusable — learn the shape, fill the slots):
#     @ ~ ( ^_-1  &  ^_-2  &  ^_-3 )
#     │ │      └────────┴────────┴ three separate things THEY said across the chat
#     │ └ ~ distils the weave to its essence
#     └ @ formalises it into one professional requirement line
#
# nlir's real strength: read several scattered messages and hand back "here's what you're
# REALLY asking for." Point the ^_-N selectors at whichever turns matter. Grounding/reference
# lane. Showcase card: showcase/nlir-cited-synthesis.png
#
# Real output (copilot/claude, LIVE — this script re-runs it):
#   "The redesign should aim to simplify and declutter the user interface, ensure reliable
#    functionality in offline conditions, and deliver high-performance analytics, even for
#    accounts with substantial data volumes."
#
# REUSE IT:  @~(^_-1 & ^_-2 & ^_-3)   — synthesise several of their points into one position.
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

EXPR="@~(^_-1 & ^_-2 & ^_-3)"

echo "move:       the cited synthesis -- @~(^_-1 & ^_-2 & ^_-3)"
echo "chat:       three scattered asks: 'make it fast' · 'work offline' · 'it's too cluttered'"
echo "---"
"$NLIR" ${NLIR_CONFIG:+--config "$NLIR_CONFIG"} ${NLIR_MODEL:+--model "$NLIR_MODEL"} --context-file "$CTX" --mode llm -e "$EXPR"
