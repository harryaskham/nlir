#!/usr/bin/env bash
# nlir-golf · aur1 · #41 — "lists are flat" (a structural law: nesting is transparent)
#
# A structural law, and a deterministic one — no model needed to see it. nlir lists
# do NOT nest: [[a,b],[c,d]] flattens straight to [a,b,c,d]. Grouping brackets carry
# NO structure, which means list construction is ASSOCIATIVE — where you put the
# inner brackets makes no difference to the result.
#
#   FLATTENING (deterministic)   [[a,b],[c,d]]  ==  [a,[b,c],d]  ==  [a,b,c,d]
#     nlir -e "[['a','b'],['c','d']]"  →  a / b / c / d      (four items, flat)
#
# The payoff is COMPOSABILITY of view-panels. My #40 five-lenses is a flat list of
# ops; because lists flatten, you can build panels from SUB-panels and glue them:
#   [[#x, ~x], [!x, x?]]  ==  [#x, ~x, !x, x?]   — two lens-pairs → one 4-lens panel
#     #x  → "Legacy API sunset"          ~x → "Sunset the legacy API."
#     !x  → "we should not sunset…"      x? → "Should we sunset the legacy API?"
#
# So a "topic+gist" pair and a "counter+question" pair concatenate into one panel
# with no wrapper nesting to unpack. Like msm0's `&` (an ordered JOIN, not boolean
# ∧), the list constructor is a flattening concat — structure lives in ORDER, not
# in bracket depth. Build big outputs from small ones, freely.
#
# Run:  ./examples/golf-aur1-41-flatlist.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
C='we should sunset the legacy API'

say "LISTS ARE FLAT  [[a,b],[c,d]] == [a,b,c,d]  — nesting is transparent (deterministic, no model)"
echo   "  [['a','b'],['c','d']] =>"; "$NLIR" -e "[['a','b'],['c','d']]" --quiet | sed 's/^/      /'

say "PAYOFF: compose view-panels — [[#x,~x],[!x,x?]] is one flat 4-lens panel (two pairs glued)"
"$NLIR" -e "[[#'$C',~'$C'],[!'$C','$C'?]]" --quiet | sed 's/^/  • /'

say "Structure lives in ORDER, not bracket depth — like msm0's & (a flattening JOIN). Build big from small."
