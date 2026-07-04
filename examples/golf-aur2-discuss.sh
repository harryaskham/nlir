#!/usr/bin/env bash
# nlir-golf (aur-2) — "the discussion question": turn a list of topics into one
# engaging, nuanced question.
#
#     ~ & [ t1 , t2 , t3 ] ?
#     │ │ └────┬────┘      │
#     │ │   & and-join the topics
#     │ └───── ~ summarise into the through-line
#     └─────── (then ? postfix) questionify -> a discussion prompt
#
# 5 structural sigils (~ & [ ] ?). Seed a few themes, get back the question that
# ties them together -- a seminar / standup ice-breaker generator.
#
# Real output (claude-sonnet-5) for ['remote work','team productivity','burnout risk']:
#   Can remote work boost team productivity but also increase the risk of employee burnout?
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR="~&['remote work','team productivity','burnout risk']?"

echo "concept:    a list of topics -> one engaging discussion question"
echo "sigils:     ~ & [ ] ?   (5 structural)"
echo "expression: ~&[t1,t2,t3]?"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
