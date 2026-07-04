#!/usr/bin/env bash
# nlir TARGET-GOLF (aur-2 #60) — reverse game via : (simplify): FINANCE jargon
# -> plain, and : reaches for the "snowball" analogy on its own.
#
# TARGET (~175 chars):
#   "Compound interest means you earn interest on your original money AND on the
#    interest it has already earned, so your savings snowball and grow faster the
#    longer you leave them."
#
# EXPRESSION (161 chars):
#   :'compound interest is interest calculated on both the initial principal and the accumulated interest from previous periods so your money grows faster over time'
#
# Real output (claude-sonnet-5):
#   "Compound interest is when you earn extra money not just on the money you started
#    with, but also on the extra money you already earned. So your money grows faster
#    and faster the longer you keep it saved, kind of like a snowball getting bigger
#    as it rolls!"
# Closeness: same mechanism (interest on principal + accumulated interest -> faster
# growth), plain + the same snowball analogy (high), 8% shorter.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

TARGET="Compound interest means you earn interest on your original money AND on the interest it has already earned, so your savings snowball and grow faster the longer you leave them."
EXPR=":'compound interest is interest calculated on both the initial principal and the accumulated interest from previous periods so your money grows faster over time'"

echo "TARGET (${#TARGET} chars): $TARGET"
echo "EXPR   (${#EXPR} chars): $EXPR"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
