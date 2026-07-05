#!/usr/bin/env bash
# nlir POWER-MOVE (aur-2) — "the computed constant": compute a figure ONCE, name it, then reuse it
# everywhere in the message. Every mention stays consistent, and you adjust the inputs in ONE place.
#
# THE MOVE (reusable):
#     NAME='<a calc>' ; @&[ "... $NAME ...", "... $NAME ...", ... ]
#     └ bind the RESULT of the calculation   └ reuse $NAME wherever the figure appears
#
# The computed sibling of the templated message: instead of binding a string, you bind the RESULT of an
# arithmetic expression ('2500'*'12'), so the figure is worked out once and dropped in wherever you write
# "$NAME". Two payoffs: (1) the number can never disagree with itself across the message; (2) change the
# calc in one spot and every mention re-renders. (This even works offline in --mode det.)
#
# THE RULE (same as templated message): interpolation needs DOUBLE quotes — "$NAME" fills it, '$NAME' not.
#
# Filled example:
#   budget='2500'*'12';
#   @&["our annual infra budget is $budget dollars",
#      "at $budget we can just afford two more regions"]
#
# Real output (claude-sonnet-5), the computed 30000 reused + formatted:
#   "Our annual infrastructure budget is $30,000, which is sufficient to accommodate two additional
#    regions."
#
# REUSE IT:  NAME='<a calc over quoted numbers>'; @&["...$NAME...", "...$NAME..."]
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR="budget='2500'*'12';@&[\"our annual infra budget is \$budget dollars\",\"at \$budget we can just afford two more regions\"]"

echo "move:       the computed constant -- NAME='<a calc>'; @&[\"...\$NAME...\"]  (compute once, reuse everywhere)"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
