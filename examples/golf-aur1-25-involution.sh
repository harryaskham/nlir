#!/usr/bin/env bash
# nlir-golf · aur1 · #25 — "the involution law" (operator algebra)
#
# Completing a little trilogy on what REPETITION does to an operator. Negation is
# an INVOLUTION — its own inverse: apply it twice and you land back where you
# started; three times equals once. Period 2, like flipping a switch.
#
#   INVOLUTION   !!x  ≈  x      !!!x  ≈  !x
#     x     "the migration is safe to run during business hours"
#     !x    "the migration is NOT safe to run during business hours"
#     !!x   "the migration is safe to run during business hours"   (flipped back!)
#     !!!x  == !x                                                   (period 2)
#
# Three operators, three algebraic characters under repetition:
#     !  INVOLUTION     — period 2, !!x = x        (this one)
#     @  SATURATION     — fixpoint after 1, @@x ≈ @x (#23, register ceiling)
#     ~  INTENSIFICATION— monotonic, ~~~x distils harder each pass (#05)
# Same "just repeat the sigil" gesture; completely different dynamics. That's the
# operator's algebra showing through the LLM.
#
# Run:  ./examples/golf-aur1-25-involution.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
S='the migration is safe to run during business hours'

say "INVOLUTION  ! / !! / !!!  — negation is self-inverse: !!x flips back to x"
echo   "  x    : $S"
echo -n "  !x   => "; "$NLIR" -e "!'$S'" --quiet
echo -n "  !!x  => "; "$NLIR" -e "!!'$S'" --quiet
echo -n "  !!!x => "; "$NLIR" -e "!!!'$S'" --quiet

say "! period-2, @ fixpoint (#23), ~ monotonic (#05) — three ops, three algebras, one gesture."
