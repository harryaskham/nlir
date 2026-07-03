#!/usr/bin/env bash
# nlir-golf · aur1 · #08 — "steelman vs strawman"
#
# Compose register ops in OPPOSITE directions and you manufacture the strongest
# and the weakest framing of the very same claim — debate prep in one list.
#
#   STEELMAN   >@c   expand ∘ formalise → the fullest, most authoritative case
#   STRAWMAN   <:c   shorten ∘ simplify → the flimsiest one-line dismissal
#   PAIR       [>@c , <:c]     both, side by side
#
# The asymmetry is the lesson: argued to the hilt vs waved away in a breath. `>@`
# piles on supporting detail in confident prose; `<:` strips it to a throwaway
# line. Same seed, opposite rhetorical poles — pairs with #06's devil's-advocate
# (@!x) to give you the whole argument surface from one claim.
#
# Run:  ./examples/golf-aur1-08-steelman.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
C='we should adopt microservices'

say "STEELMAN  >@c  — expand ∘ formalise = the fullest, most authoritative case"
echo -n "  => "; "$NLIR" -e ">@'$C'" --quiet

say "STRAWMAN  <:c  — shorten ∘ simplify = the flimsiest one-line dismissal"
echo -n "  => "; "$NLIR" -e "<:'$C'" --quiet

say "Same seed, opposite poles: [>@c , <:c] = the whole argument surface. (pairs with @!x, #06)"
