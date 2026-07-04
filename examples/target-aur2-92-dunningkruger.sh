#!/usr/bin/env bash
# nlir TARGET-GOLF (aur-2 #92) — reverse game via : (simplify): PSYCHOLOGY jargon
# (the Dunning-Kruger effect) -> plain, 29% shorter; : even adds the WHY.
#
# TARGET (~228 chars):
#   "The Dunning-Kruger effect is when people who aren't very good at something think
#    they're much better than they are, while people who are actually skilled tend to
#    doubt themselves -- because knowing a little makes you overconfident."
#
# EXPRESSION (161 chars):
#   :'the dunning kruger effect is a cognitive bias where people with low ability at a task overestimate their competence while experts tend to underestimate theirs'
#
# Real output (claude-sonnet-5):
#   "Sometimes people who aren't very good at something think they're really good at it,
#    because they don't know enough to see their own mistakes. But people who are
#    actually experts often think they're not as good as they really are, because they
#    know just how much there is still to learn."
# Closeness: same idea (low-ability overestimate; experts underestimate), plain (high),
# 29% shorter -- and : supplied the MECHANISM (can't see your own mistakes / know how
# much is left) my target only hinted at.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

TARGET="The Dunning-Kruger effect is when people who aren't very good at something think they're much better than they are, while people who are actually skilled tend to doubt themselves -- because knowing a little makes you overconfident."
EXPR=":'the dunning kruger effect is a cognitive bias where people with low ability at a task overestimate their competence while experts tend to underestimate theirs'"

echo "TARGET (${#TARGET} chars): $TARGET"
echo "EXPR   (${#EXPR} chars): $EXPR"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
