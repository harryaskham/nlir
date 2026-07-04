#!/usr/bin/env bash
# nlir-golf (aur-2) — "the syllogism": hand nlir two premises, get the conclusion.
#
#     ~ & [ 'all men are mortal' , 'socrates is a man' ]
#     │ │ └──────────────┬───────────────────┘
#     │ │   & and-join the premises into one proposition
#     │ └───── ~ summarise it -> the model DEDUCES the entailment
#     └─────── (~ alone lands the conclusion)
#
# 4 structural sigils (~ & [ ]). Summarising a conjunction of premises makes the
# model perform the inference -- deductive reasoning as a side effect of "gist".
#
# Real output (claude-sonnet-5) for
#   ['all men are mortal','socrates is a man']:
#   Socrates, as a man, is mortal.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR="~&['all men are mortal','socrates is a man']"

echo "concept:    derive the conclusion from two premises (a syllogism)"
echo "sigils:     ~ & [ ]   (4 structural)"
echo "expression: ~&[premise1,premise2]"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
