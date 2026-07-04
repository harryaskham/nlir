#!/usr/bin/env bash
# nlir TARGET-GOLF (aur-2 #44) — reverse game via : (simplify): PSYCHOLOGY jargon
# -> plain, 15% shorter too.
#
# TARGET (~181 chars):
#   "Cognitive dissonance is the uncomfortable feeling you get when you believe two
#    things that contradict each other, or when you do something that goes against
#    what you think is right."
#
# EXPRESSION (153 chars):
#   :'cognitive dissonance is the mental discomfort a person feels when they hold two contradictory beliefs or when their actions conflict with their values'
#
# Real output (claude-sonnet-5):
#   "Cognitive dissonance is that funny, uncomfortable feeling you get inside when
#    you believe two things that don't agree with each other, or when what you do
#    doesn't match what you think is right."
# Closeness: same concept (discomfort from clashing beliefs / actions-vs-values),
# plain + warm (high), 15% shorter. : keeps the two triggers, drops the textbook tone.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

TARGET="Cognitive dissonance is the uncomfortable feeling you get when you believe two things that contradict each other, or when you do something that goes against what you think is right."
EXPR=":'cognitive dissonance is the mental discomfort a person feels when they hold two contradictory beliefs or when their actions conflict with their values'"

echo "TARGET (${#TARGET} chars): $TARGET"
echo "EXPR   (${#EXPR} chars): $EXPR"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
