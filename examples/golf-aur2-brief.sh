#!/usr/bin/env bash
# nlir-golf (aur-2) — "the executive brief": turn a bundle of rough notes into
# one polished status line.
#
#     @ ~ & [ n1 , n2 , n3 ]
#     │ │ └── & and-join the rough notes into one blob
#     │ └──── ~ summarise the pile to its essence
#     └────── @ formalise it to a professional register
#
# 5 structural sigils (@ ~ & [ ]) over a spread list, depth-4 nested stack:
# raw standup scribbles -> a brief you could paste into a status update.
#
# Real output (claude-sonnet-5) for
#   ['users complaining about slow load times', 'mobile checkout broken on iOS',
#    'ship the new pricing page by friday']:
#   Users have reported degraded page load performance and a non-functional
#   checkout process on iOS mobile devices. Additionally, the new pricing page
#   is required to launch by Friday.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

N1='users complaining about slow load times'
N2='mobile checkout broken on iOS'
N3='ship the new pricing page by friday'
EXPR="@~&['$N1','$N2','$N3']"

echo "concept:    rough notes -> one polished status brief"
echo "sigils:     @ ~ & [ ]   (5 structural)"
echo "expression: @~&[n1,n2,n3]"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
