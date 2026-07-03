#!/usr/bin/env bash
# nlir-golf (aur-2) — "the dilemma": turn a set of options into the single
# decision question that frames them.
#
#     | [ 'option a' , 'option b' ] ?
#     │   └────────┬────────┘       │
#     │   or-join the options -> "a or b"
#     └─────────────────────────────  ? questionify the whole -> the choice question
#
# 4 structural sigils (| [ ] ?) over a spread list. A decision-framing tool:
# hand it the horns, get back the dilemma.
#
# Real output (claude-sonnet-5) for
#   ['ship it now with known bugs', 'delay the release for more polish']:
#   Should we ship it now with known bugs or delay the release for more polish?
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

A='ship it now with known bugs'
B='delay the release for more polish'
EXPR="|['$A','$B']?"

echo "concept:    frame a set of options as the decision question"
echo "sigils:     | [ ] ?   (4 structural)"
echo "expression: |[a,b]?"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
