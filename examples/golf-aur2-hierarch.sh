#!/usr/bin/env bash
# nlir-golf (aur-2) — "theme of themes": discover the hidden abstraction that
# unifies several CLUSTERS of documents (hierarchical / tree-recursive synthesis).
#
# Where golf-aur2-theme.sh was a flat corpus (~&[#,#,#]), this nests the SAME
# synthesis operator inside itself — a depth-4 tree over the message-free stack:
#
#     ~ & [  ~&[#a1,#a2]  ,  ~&[#b1,#b2]  ]
#     │ │      └─ theme of cluster A ┘  └ theme of cluster B ┘
#     │ │        (subject→join→summary, ×2, concurrent)
#     │ └── & join the two cluster-themes
#     └──── ~ summarise the join → the META-theme across clusters
#
# 10 operator sigils (~×3 &×3 #×4) turn two clusters of unrelated-looking docs
# into the single abstraction they secretly share. ~10 model calls; the 4 leaf
# subject-extractions run concurrently.
#
# Real output (claude-sonnet-5) — cluster A = swarm biology, cluster B = human
# aggregation systems:
#   Honeybees, ants, prediction markets, and Wikipedia all achieve effective
#   outcomes through decentralized collective processes rather than centralized
#   control.
#
# (i.e. nlir surfaced "emergence / collective intelligence" — a concept in
# NEITHER cluster's text — purely from the tree of transforms.)
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

# cluster A — collective behaviour in nature
A1='A honeybee swarm chooses a new nest site as thousands of scout bees dance to build consensus.'
A2='Ant colonies discover the shortest route to food via pheromone trails reinforced by many ants.'
# cluster B — human/technological aggregation
B1='Prediction markets aggregate the scattered guesses of many independent traders into one accurate forecast.'
B2='Wikipedia articles converge on accuracy through the small edits of countless anonymous contributors.'

EXPR="~&[~&[#'$A1',#'$A2'],~&[#'$B1',#'$B2']]"

echo "concept:    the hidden abstraction unifying two clusters of documents"
echo "sigils:     ~ & [ ~&[#,#] , ~&[#,#] ]   (depth-4 tree; 10 operator sigils)"
echo "expression: ~&[ ~&[#a1,#a2] , ~&[#b1,#b2] ]"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
