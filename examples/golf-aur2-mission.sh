#!/usr/bin/env bash
# nlir-golf (aur-2) — "the mission statement": distil a list of values into one
# punchy, quotable line.
#
#     < ~ & [ v1 , v2 , v3 ]
#     │ │ └── & and-join the values
#     │ └──── ~ summarise them
#     └────── < shorten to a crisp motto
#
# 5 structural sigils (< ~ & [ ]). Where the executive brief (@~&) FORMALISES a
# pile of notes, the mission TIGHTENS a pile of values -- `<` is the punch dial.
#
# Real output (claude-sonnet-5) for
#   ['delight our customers','move fast','stay lean']:
#   Delight customers, move fast, stay lean.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR="<~&['delight our customers','move fast','stay lean']"

echo "concept:    a list of values -> one punchy mission line"
echo "sigils:     < ~ & [ ]   (5 structural)"
echo "expression: <~&[v1,v2,v3]"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
