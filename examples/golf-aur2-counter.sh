#!/usr/bin/env bash
# nlir-golf (aur-2) — "the counter-position": from a bundle of someone's claims,
# state the opposing camp's coherent one-line position (a debate / steelman tool).
#
#     ~ ! & [ c1 , c2 ]
#     │ │ └── & fluently and-join the claims into one proposition
#     │ └──── ! negate that whole joined proposition
#     └────── ~ summarise it into one clean line
#
# 5 structural sigils (~ ! & [ ]) over a spread list — depth-4 nested stack.
# Turns a set of assertions into the rebuttal side's thesis.
#
# Real output (claude-sonnet-5) for
#   ['smartphones harm kids attention spans', 'schools should ban phones entirely']:
#   Smartphones don't harm kids' attention spans, so schools shouldn't fully ban them.
# (note the preserved "so" — it negated the whole bundle AND kept its internal logic.)
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

C1='smartphones harm kids attention spans'
C2='schools should ban phones entirely'
EXPR="~!&['$C1','$C2']"

echo "concept:    the opposing camp's one-line position, from a bundle of claims"
echo "sigils:     ~ ! & [ ]   (5 structural)"
echo "expression: ~!&[c1,c2]"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
