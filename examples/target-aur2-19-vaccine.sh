#!/usr/bin/env bash
# nlir TARGET-GOLF (aur-2 #19) — reverse game via ~> (summary of expand): a
# science/health one-liner from a 21-char seed.
#
# TARGET (~133 chars):
#   "A vaccine teaches your immune system to recognize a germ by showing it a harmless piece, so it can fight the real thing faster later."
#
# EXPRESSION (21 chars):
#   ~>'how vaccines work'
#
# Real output (claude-sonnet-5):
#   "Vaccines train the immune system to recognize a pathogen safely, creating
#    memory cells that enable a fast, protective response upon future exposure."
# Closeness: same concept (safe training -> faster future response), one dense
# sentence (high). 84% shorter.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

TARGET="A vaccine teaches your immune system to recognize a germ by showing it a harmless piece, so it can fight the real thing faster later."
EXPR="~>'how vaccines work'"

echo "TARGET (${#TARGET} chars): $TARGET"
echo "EXPR   (${#EXPR} chars): $EXPR"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
