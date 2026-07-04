#!/usr/bin/env bash
# nlir TARGET-GOLF (aur-2 #108) — reverse game via ~> (summary of expand): a dense
# TECHNICAL one-liner defining a software-delivery concept from a 26-char seed.
#
# TARGET (~177 chars):
#   "A feature flag is a switch in your code that lets you turn a feature on or off without
#    deploying new code, so you can release to some users, test safely, or roll back
#    instantly."
#
# EXPRESSION (26 chars):
#   ~>'what is a feature flag'
#
# Real output (claude-sonnet-5):
#   "A feature flag is a code-level toggle that lets teams enable or disable functionality
#    without deploying new code, supporting safer rollouts, testing, and risk management in
#    software delivery."
# Closeness: same core (a toggle to turn a feature on/off without deploying -> safer
# rollouts, testing, rollback), technical register (high), 85% shorter -- 26 chars into a
# full definition.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

TARGET="A feature flag is a switch in your code that lets you turn a feature on or off without deploying new code, so you can release to some users, test safely, or roll back instantly."
EXPR="~>'what is a feature flag'"

echo "TARGET (${#TARGET} chars): $TARGET"
echo "EXPR   (${#EXPR} chars): $EXPR"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
