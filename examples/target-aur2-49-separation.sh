#!/usr/bin/env bash
# nlir TARGET-GOLF (aur-2 #49) — reverse game via : (simplify): CIVICS jargon
# -> plain, 11% shorter.
#
# TARGET (~174 chars):
#   "Separation of powers means a government is split into three parts -- one makes
#    the laws, one carries them out, and one judges them -- so no single part can
#    grab too much power."
#
# EXPRESSION (154 chars):
#   :'the separation of powers divides a government into three branches legislative executive and judicial so that no single branch can gain too much control'
#
# Real output (claude-sonnet-5):
#   "A government has three parts that share the job of running the country: one
#    part makes the rules, one part makes sure the rules are followed, and one part
#    decides if the rules are being used fairly. They split the job this way so no
#    single part gets too much power."
# Closeness: same structure (three branches with distinct roles; no single one too
# powerful), plain (high), 11% shorter. : renders legislative/executive/judicial as
# make-the-rules / enforce-them / judge-them.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

TARGET="Separation of powers means a government is split into three parts -- one makes the laws, one carries them out, and one judges them -- so no single part can grab too much power."
EXPR=":'the separation of powers divides a government into three branches legislative executive and judicial so that no single branch can gain too much control'"

echo "TARGET (${#TARGET} chars): $TARGET"
echo "EXPR   (${#EXPR} chars): $EXPR"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
