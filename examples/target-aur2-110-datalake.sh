#!/usr/bin/env bash
# nlir TARGET-GOLF (aur-2 #110) — reverse game via ~> (summary of expand): a dense
# TECHNICAL one-liner defining a data-engineering concept from a 23-char seed.
#
# TARGET (~203 chars):
#   "A data lake is a big central store where you dump all your raw data -- structured or
#    not -- in its original form, so you can keep everything cheaply now and figure out how
#    to analyze or transform it later."
#
# EXPRESSION (23 chars):
#   ~>'what is a data lake'
#
# Real output (claude-sonnet-5):
#   "A data lake is a centralized repository storing raw structured, semi-structured, and
#    unstructured data using schema-on-read, enabling flexible big data analytics, ML, and
#    data science, but with distinct benefits and management challenges compared to
#    traditional warehouses."
# Closeness: same core (central store of raw data in original form, keep everything,
# analyze later / schema-on-read), technical register (high), 89% shorter.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

TARGET="A data lake is a big central store where you dump all your raw data -- structured or not -- in its original form, so you can keep everything cheaply now and figure out how to analyze or transform it later."
EXPR="~>'what is a data lake'"

echo "TARGET (${#TARGET} chars): $TARGET"
echo "EXPR   (${#EXPR} chars): $EXPR"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
