#!/usr/bin/env bash
# nlir POWER-MOVE (aur-0) — "the self-red-team": write, then argue against your own gist.
#
# THE MOVE (reusable — learn the shape, fill the slots):
#     k = @>'<your proposal>' ; [ $k , >!~$k ]
#     │       │                    │     └ >!~$k = expand·negate·summarise your OWN draft
#     │       │                    │              = the strongest developed case AGAINST it
#     │       │                    └ $k = your proposal
#     │       └ @> expands your proposal into a formal memo
#     └ = binds it so the rebuttal can reference it
#
# nlir's real strength: pressure-test your own thinking before you send. You get your proposal
# AND its steelmanned rebuttal, side by side, from one line. Distinct from the self-summarizing
# memo (which CONDENSES; this CHALLENGES). Self-reflection lane. Showcase: showcase/nlir-self-red-team.png
#
# Real output (copilot/claude, LIVE — this script re-runs it): a formal hiring-freeze proposal,
# followed by the developed case against it ("...refrain from a complete, blanket freeze... hold
# off until the Q3 review... avoids a premature, overly broad action...").
#
# REUSE IT:  k=@>'<your draft>';[$k,>!~$k]   — your draft plus its own strongest rebuttal.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR="_sep=\n\n;k=@>'freeze all hiring until Q3';[\$k,>!~\$k]"

echo "move:       the self-red-team -- k=@>'X';[\$k,>!~\$k]"
echo "---"
"$NLIR" ${NLIR_CONFIG:+--config "$NLIR_CONFIG"} ${NLIR_MODEL:+--model "$NLIR_MODEL"} --context-file "$CTX" --mode llm -e "$EXPR"
