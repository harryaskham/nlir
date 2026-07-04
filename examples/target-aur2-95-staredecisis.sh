#!/usr/bin/env bash
# nlir TARGET-GOLF (aur-2 #95) — reverse game via : (simplify): LEGAL jargon
# (stare decisis) -> plain, ~even length.
#
# TARGET (~175 chars):
#   "Stare decisis is the rule that courts should stick to earlier decisions when a new
#    case is similar -- so the law stays consistent and people can predict how it will
#    be applied."
#
# EXPRESSION (168 chars):
#   :'stare decisis is the legal principle that courts should follow the precedents set by previous decisions when ruling on cases with similar facts to ensure consistency'
#
# Real output (claude-sonnet-5):
#   "'Stare decisis' is a rule that says judges should look at how courts decided
#    similar cases before, and make their decisions match those older ones. This helps
#    keep things fair and the same for everyone."
# Closeness: same idea (follow earlier decisions on similar cases -> consistency), plain
# (high), ~even length. : renders "precedent" as "how courts decided similar cases before".
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

TARGET="Stare decisis is the rule that courts should stick to earlier decisions when a new case is similar -- so the law stays consistent and people can predict how it will be applied."
EXPR=":'stare decisis is the legal principle that courts should follow the precedents set by previous decisions when ruling on cases with similar facts to ensure consistency'"

echo "TARGET (${#TARGET} chars): $TARGET"
echo "EXPR   (${#EXPR} chars): $EXPR"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
