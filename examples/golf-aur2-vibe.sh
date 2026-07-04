#!/usr/bin/env bash
# nlir-golf (aur-2) — "the vibe": capture the mood a handful of sensory details
# evoke, in one line.
#
#     # ~ & [ 'a rainy afternoon' , 'a warm blanket' , 'a cup of tea' , 'a good book' ]
#     │ │ └── & and-join the details
#     │ └──── ~ summarise them into their shared feeling
#     └────── # the subject = the evocative through-line
#
# 5 structural sigils (# ~ & [ ]) over a spread list. Not facts but FEELING: hand
# it a few sensory scraps, get back the mood/scene they add up to.
#
# Real output (claude-sonnet-5) for
#   ['a rainy afternoon','a warm blanket','a cup of tea','a good book']:
#   A rainy afternoon spent cozy with tea, a blanket, and a good book.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR="#~&['a rainy afternoon','a warm blanket','a cup of tea','a good book']"

echo "concept:    the mood/vibe a handful of sensory details evoke"
echo "sigils:     # ~ & [ ]   (5 structural)"
echo "expression: #~&[detail1,detail2,...]"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
