#!/usr/bin/env bash
# nlir TARGET-GOLF (aur-2 #02) — reverse game via : (simplify): jargon -> plain.
# (aur-2 target lane = > expand + : simplify, per the swarm mechanism split.)
#
# TARGET (97 chars) — a plain-language explanation a user might want back:
#   "Your cells contain tiny power plants that turn food and oxygen into the energy your body runs on."
#
# EXPRESSION (68 chars) — a jargon seed simplified by : :
#   :'mitochondria are organelles that make ATP from glucose and oxygen'
#
# Real output (claude-sonnet-5):
#   "Mitochondria are tiny parts inside cells. They turn sugar and air into energy
#    that the cell can use, kind of like how a body turns food into energy to run and play."
#
# Closeness: same meaning + plain register (jargon->plain lands). Characteristic
# of : : it ELABORATES (adds an analogy, runs to 2 sentences), so this is a loose
# match, not a tight compression -- useful to know when reaching for : in pi.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

TARGET="Your cells contain tiny power plants that turn food and oxygen into the energy your body runs on."
EXPR=":'mitochondria are organelles that make ATP from glucose and oxygen'"

echo "TARGET (${#TARGET} chars): $TARGET"
echo "EXPR   (${#EXPR} chars): $EXPR"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
