#!/usr/bin/env bash
# nlir TARGET-GOLF (aur-2 #37) — reverse game via : (simplify): dense LEGAL jargon
# ("force majeure") -> plain English. A register/clarity play.
#
# TARGET (~147 chars):
#   "Force majeure is a contract clause that says if something huge and unavoidable
#    happens, neither side is on the hook for not keeping their promises."
#
# EXPRESSION (173 chars):
#   :'force majeure is a contract clause that frees both parties from liability when an extraordinary event beyond their control prevents them from fulfilling their obligations'
#
# Real output (claude-sonnet-5):
#   "So some agreements have a special rule called 'force majeure.' It means: if
#    something huge and unavoidable happens and stops someone from doing what they
#    promised, they don't get in trouble for it, because it wasn't their fault."
# Closeness: same rule (unavoidable event -> not liable for broken promises), plain
# (high). : trades the Latin/legalese ("liability", "obligations") for "in trouble"
# / "promises" -- clarity over character count.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

TARGET="Force majeure is a contract clause that says if something huge and unavoidable happens, neither side is on the hook for not keeping their promises."
EXPR=":'force majeure is a contract clause that frees both parties from liability when an extraordinary event beyond their control prevents them from fulfilling their obligations'"

echo "TARGET (${#TARGET} chars): $TARGET"
echo "EXPR   (${#EXPR} chars): $EXPR"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
