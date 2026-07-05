#!/usr/bin/env bash
# nlir POWER-MOVE (aur-0) — "the full layered reply": a whole considered response in ONE expression.
# This is Harry's original example, executed for real: reply + modify + reference + caveat + restyle
# + a reflection on your own summary.
#
# THE MOVE (reusable — learn the shape, fill the slots):
#     k = @ ( ^-1 & '<modification>' & ^_-1 & '<caveat>' ) ; [ $k , ~$k ]
#     │     │    │        │              │        │             │    └ ~$k = reflect on your own summary
#     │     │    │        │              │        │             └ $k  = the full reply
#     │     │    │        │              │        └ your caveat over all of it
#     │     │    │        │              └ ^_-1 = an earlier point you REFERENCE
#     │     │    │        └ your modification to their idea
#     │     │    └ ^-1 = the agent's suggestion you're replying to
#     │     └ @ restyles the whole weave into a formal register
#     └ = binds the reply so you can reflect on it
#
# nlir's real strength: SIX communicative moves — reply, modify, reference, caveat, restyle,
# self-reflect — in a handful of sigils reading live chat. The showpiece for "a compressed
# language of thought." Showcase card: showcase/nlir-full-layered-reply.png
#
# Real output (copilot/claude, LIVE — this script re-runs it): a formal reply recommending the
# e2e tests but starting with the payment step, referencing the QA-capacity constraint and the
# no-launch-slip caveat — followed by its own one-line gist.
#
# REUSE IT:  k=@(^-1 & '<change>' & ^_-N & '<caveat>');[$k,~$k]
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT
cat > "$CTX" <<'JSON'
{"_messages":[
{"role":"user","content":"heads up, we're really short on QA capacity this quarter"},
{"role":"assistant","content":"let's add end-to-end tests for the whole checkout flow before the launch"}
]}
JSON

EXPR="_sep=\n\n;k=@(^-1 & 'start with just the payment step' & ^_-1 & 'only if it wont slip launch');[\$k,~\$k]"

echo "move:       the full layered reply -- k=@(^-1 & mod & ^_-1 & caveat);[\$k,~\$k]"
echo "chat:       you: 'short on QA capacity'  ·  agent: 'add e2e tests for the whole checkout flow'"
echo "---"
"$NLIR" ${NLIR_CONFIG:+--config "$NLIR_CONFIG"} ${NLIR_MODEL:+--model "$NLIR_MODEL"} --context-file "$CTX" --mode llm -e "$EXPR"
