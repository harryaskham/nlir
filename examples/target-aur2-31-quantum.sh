#!/usr/bin/env bash
# nlir TARGET-GOLF (aur-2 #31) — reverse game via ~> (summary of expand): a
# one-line, technical-register definition of a hard topic from a 29-char seed.
#
# TARGET (~169 chars):
#   "Quantum computing uses the strange rules of quantum physics to process many
#    possibilities at once, potentially solving certain problems far faster than
#    normal computers."
#
# EXPRESSION (29 chars):
#   ~>'what is quantum computing'
#
# Real output (claude-sonnet-5):
#   "Quantum computing uses qubits, superposition, and entanglement to compute in
#    fundamentally different ways than classical binary-based computers, offering
#    unique advantages."
# Closeness: same core (quantum physics -> a new kind of computation, big
# advantage), but ~> lands the TECHNICAL register (qubits/superposition/
# entanglement) vs the target's plainer phrasing (moderate-high). 83% shorter.
# (For a plainer version, reach for :~> instead of ~>.)
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

TARGET="Quantum computing uses the strange rules of quantum physics to process many possibilities at once, potentially solving certain problems far faster than normal computers."
EXPR="~>'what is quantum computing'"

echo "TARGET (${#TARGET} chars): $TARGET"
echo "EXPR   (${#EXPR} chars): $EXPR"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
