#!/usr/bin/env bash
# nlir TARGET-GOLF (aur-2 #32) — reverse game via : (simplify): BIOLOGY jargon
# -> plain, and : supplies its own everyday analogy (a battery).
#
# TARGET (~106 chars):
#   "Mitochondria are the tiny power plants inside your cells: they turn food into the energy the cell runs on."
#
# EXPRESSION (114 chars):
#   :'mitochondria are the organelles that generate most of the chemical energy a cell needs, stored as ATP molecules'
#
# Real output (claude-sonnet-5):
#   "Mitochondria are tiny parts inside a cell. Their job is to make energy for the
#    cell, kind of like a battery. This energy is stored in little packets called ATP."
# Closeness: same concept (tiny cell parts that make + store energy), plain + its
# own analogy (battery vs power plant) (high). Length ~even, but the register drops
# from textbook to kitchen-table -- : trades jargon for CLARITY, not characters.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

TARGET="Mitochondria are the tiny power plants inside your cells: they turn food into the energy the cell runs on."
EXPR=":'mitochondria are the organelles that generate most of the chemical energy a cell needs, stored as ATP molecules'"

echo "TARGET (${#TARGET} chars): $TARGET"
echo "EXPR   (${#EXPR} chars): $EXPR"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
