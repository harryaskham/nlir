#!/usr/bin/env bash
# nlir TARGET-GOLF (aur-2 #59) — reverse game via : (simplify): MEDICINE jargon
# -> plain, on the classic "why don't antibiotics help my cold?" misconception.
#
# TARGET (~130 chars):
#   "Antibiotics only work against bacteria, not viruses -- so they won't do anything
#    for a cold or the flu, which are caused by viruses."
#
# EXPRESSION (110 chars):
#   :'antibiotics kill bacteria but have no effect on viruses which is why they do not help with colds or the flu'
#
# Real output (claude-sonnet-5):
#   "Antibiotics are medicines that can kill germs called bacteria. But there's
#    another kind of germ called a virus, and antibiotics can't fight those. Colds
#    and the flu are caused by viruses, so antibiotics can't make them better."
# Closeness: same fact (antibiotics kill bacteria not viruses -> useless on viral
# colds/flu), plain + very accessible "germs" framing (high). : expands into a fuller
# kid-friendly explanation (register play, not a length win).
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

TARGET="Antibiotics only work against bacteria, not viruses -- so they won't do anything for a cold or the flu, which are caused by viruses."
EXPR=":'antibiotics kill bacteria but have no effect on viruses which is why they do not help with colds or the flu'"

echo "TARGET (${#TARGET} chars): $TARGET"
echo "EXPR   (${#EXPR} chars): $EXPR"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
