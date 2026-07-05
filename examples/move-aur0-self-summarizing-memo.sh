#!/usr/bin/env bash
# nlir POWER-MOVE (aur-0) — "the self-summarizing memo": write, then reflect on your own gist.
#
# THE MOVE (reusable — learn the shape, fill the slots):
#     k = >@'<your point>' ; [ $k , ~$k ]
#     │      │                  │    └ ~$k = a reflection on the summary of what you just wrote
#     │      │                  └ $k  = the memo itself
#     │      └ >@ expands your point into a formal memo
#     └ = binds that memo to k so it can be REUSED (this is the self-reference primitive —
#         no new operator needed; &[X,~X] would recompute, k=X;... computes once + reuses)
#
# nlir's real strength: "write the memo AND addendum a reflection on its own summary" — Harry's
# exact example — with zero new sigils. Self-reflection lane. Showcase: showcase/nlir-self-summarizing-memo.png
#
# Real output (copilot/claude, LIVE — this script re-runs it): a full formal decommissioning
# memo, followed by "The legacy billing API must be fully decommissioned before Q3 begins."
#
# REUSE IT:  k=<your draft>;[$k,~$k]   — anything you write, plus its own one-line gist.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR="_sep=\n\n;k=>@'sunset the legacy billing API before Q3';[\$k,~\$k]"

echo "move:       the self-summarizing memo -- k=>@'X';[\$k,~\$k]"
echo "---"
"$NLIR" ${NLIR_CONFIG:+--config "$NLIR_CONFIG"} ${NLIR_MODEL:+--model "$NLIR_MODEL"} --context-file "$CTX" --mode llm -e "$EXPR"
