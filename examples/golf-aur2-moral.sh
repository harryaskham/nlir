#!/usr/bin/env bash
# nlir-golf (aur-2) — "the shared moral": distill the common lesson from two
# unrelated cautionary tales.
#
#     # ~ & [ tale1 , tale2 ]
#     │ │ └── & and-join the two stories
#     │ └──── ~ summarise the pair to its essence
#     └────── # extract the SUBJECT = the abstract principle
#
# 5 structural sigils (# ~ & [ ]) over a spread list. Concrete stories in, the one
# abstract principle they share out -- moral / pattern extraction across domains.
#
# Real output (claude-sonnet-5) for
#   ['a boy cried wolf until no one believed him',
#    'a startup faked its metrics until investors walked away']:
#   Repeated dishonesty
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

T1='a boy cried wolf until no one believed him'
T2='a startup faked its metrics until investors walked away'
EXPR="#~&['$T1','$T2']"

echo "concept:    the shared moral of two unrelated cautionary tales"
echo "sigils:     # ~ & [ ]   (5 structural)"
echo "expression: #~&[tale1,tale2]"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
