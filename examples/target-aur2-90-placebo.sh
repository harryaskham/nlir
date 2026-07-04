#!/usr/bin/env bash
# nlir TARGET-GOLF (aur-2 #90) — reverse game via : (simplify): MEDICINE jargon
# (a placebo) -> plain; : reaches for the "sugar pill / pretend medicine" picture.
#
# TARGET (~206 chars):
#   "A placebo is a fake treatment -- like a sugar pill -- with no real medicine in it,
#    given to someone who thinks it's real. In trials, it's used to compare against the
#    real drug to see if the drug actually works."
#
# EXPRESSION (163 chars):
#   :'a placebo is an inactive substance or treatment with no therapeutic effect given to a patient who believes it is real often used as a control in clinical trials'
#
# Real output (claude-sonnet-5):
#   "A placebo is like a pretend medicine -- it doesn't really do anything to help you.
#    But the person taking it doesn't know that, so they think it might work anyway.
#    Doctors and scientists use these fake medicines when testing new real medicines, so
#    they can compare and see if the real one actually works better."
# Closeness: same idea (an inactive/fake treatment the patient believes is real, used as
# a trial control to compare against the real drug), plain (high). Runs a bit longer -- :
# went ELI5 on an approachable topic (register play).
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

TARGET="A placebo is a fake treatment -- like a sugar pill -- with no real medicine in it, given to someone who thinks it's real. In trials, it's used to compare against the real drug to see if the drug actually works."
EXPR=":'a placebo is an inactive substance or treatment with no therapeutic effect given to a patient who believes it is real often used as a control in clinical trials'"

echo "TARGET (${#TARGET} chars): $TARGET"
echo "EXPR   (${#EXPR} chars): $EXPR"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
