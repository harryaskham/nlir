#!/usr/bin/env bash
# nlir POWER-MOVE (aur-2) — "=> the escape hatch": free generation, but EARNED.
#
# HONEST FRAMING (sgu24-app's test): bare `=>"write X"` is just a prompt — any
# chatbot does that, it is NOT why you'd reach for nlir. The terse STRUCTURAL ops
# (@ formalise · : simplify · ~ distil · # subject · & weave) reach most
# communication targets in a few sigils. `=>` is the ESCAPE HATCH for the one
# thing they can't: open-ended generation. It earns its place two ways —
#   1. SPLICE live context tersely: `t=^_-1; =>"<tight instruction>: $t"` — the
#      nlir part is selecting a chat turn (^_-1) and interpolating it into a
#      CONSTRAINED instruction; the generation itself is not the point.
#   2. COMPOSE it: feed its output to a det op (`~=>"..."` = generate then distil)
#      or weave it (`@&[:^_-1, =>"..."]`), so the fuzzy step lives inside structure.
# If you can't say why an `=>` line isn't just a prompt, don't use `=>` — reach
# for the structural op that hits the target tighter.
#
# THE MOVE (reusable):
#     t=^_-1; =>"<a TIGHT, constrained instruction about their point>: $t"
#     │       │  └ "double-quote" interpolates $t / $_stdin; keep it length/format
#     │       │    bound so => obeys and stays terse
#     │       └ => = obey the instruction, return ONLY the result
#     └ SELECT + bind a live chat turn so the instruction can reference it
#
# Filled example (against the chat below):
#   t=^_-1; =>"in one sentence, the single biggest risk of: $t"
#
# Real output (claude-sonnet-5):
#   "The biggest risk is that you'll run out of time to rediscover and correctly
#    reimplement the years of hard-won billing edge cases (tax, proration, refunds,
#    currency, compliance), so you either slip Q3 or launch with money-handling
#    bugs in production."
#
# Compare: when a structural op fits, it is terser and needs no generation —
#   @~^_-1   = a formal gist of their point.
# Reach for => only when you genuinely need NEW prose, and keep it composed.
#
# REUSE IT:  t=^_-1; =>"<tight instruction>: $t"   (or)   ~=>"<gen>" to distil it
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
# => is a config.example.yaml operator; default there so the move is self-contained.
# Override NLIR_CONFIG to point => at your own generative backend.
NLIR_CONFIG="${NLIR_CONFIG:-config.example.yaml}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT
cat > "$CTX" <<'JSON'
{"_messages":[
{"role":"user","content":"we should just rewrite the whole billing service in a new language before the Q3 launch"},
{"role":"assistant","content":"that's a big rewrite right before a launch — risky"}
]}
JSON

EXPR='t=^_-1;=>"in one sentence, the single biggest risk of: $t"'

echo "move:       => the escape hatch -- t=^_-1; =>\"<tight instruction>: \$t\""
echo "why nlir:   the STRUCTURE is nlir (select ^_-1 + splice + constrain); generation is just the fuzzy step you compose"
echo "chat:       user: 'rewrite the whole billing service in a new language before Q3'"
echo "---"
"$NLIR" --config "$NLIR_CONFIG" --context-file "$CTX" --mode llm -e "$EXPR"
