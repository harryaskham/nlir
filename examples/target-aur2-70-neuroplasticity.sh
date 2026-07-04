#!/usr/bin/env bash
# nlir TARGET-GOLF (aur-2 #70) — reverse game via : (simplify): NEUROSCIENCE jargon
# (neuroplasticity) -> plain. : reaches for a paths/wires analogy and (on an
# approachable wonder-topic) runs a little long, ELI5-style.
#
# TARGET (~173 chars):
#   "Neuroplasticity is the brain's ability to rewire itself -- it keeps forming new
#    connections as you learn, practice, or recover from injury, so your brain is
#    never truly fixed."
#
# EXPRESSION (156 chars):
#   :'neuroplasticity is the brains ability to reorganize itself by forming new neural connections throughout life in response to learning experience or injury'
#
# Real output (claude-sonnet-5):
#   "Your brain can change and grow all through your life! When you learn new things,
#    practice a skill, or even get hurt, your brain can build new connections inside
#    it -- kind of like making new paths or wires. This helps your brain get better at
#    things and heal when it needs to."
# Closeness: same idea (the brain rewires via new connections, lifelong, through
# learning/practice/injury), plain + vivid (high). Runs longer -- : went ELI5 on a
# wonder-topic (register play, not a length win).
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

TARGET="Neuroplasticity is the brain's ability to rewire itself -- it keeps forming new connections as you learn, practice, or recover from injury, so your brain is never truly fixed."
EXPR=":'neuroplasticity is the brains ability to reorganize itself by forming new neural connections throughout life in response to learning experience or injury'"

echo "TARGET (${#TARGET} chars): $TARGET"
echo "EXPR   (${#EXPR} chars): $EXPR"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
