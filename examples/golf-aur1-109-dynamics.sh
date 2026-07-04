#!/usr/bin/env bash
# nlir-golf · aur1 · #109 — "operator dynamics" (repeat an operator: it either CYCLES or SATURATES)
#
# What happens if you apply the SAME operator over and over? Two behaviours, and which one you
# get is a property of the operator. Some operators CYCLE (they have a period); others SATURATE
# (they hit a fixed point and stop moving). This is the dynamical-systems view of the language.
#
#   OPERATOR DYNAMICS      x = "the deployment failed because someone skipped the tests"
#     ! (negate) — CYCLES, period 2:
#         !x   → "the deployment DIDN'T fail because someone skipped the tests"
#         !!x  → "the deployment DID fail because someone skipped the tests"   (back to x! #25)
#     @ (formalise) — SATURATES (fixed after 1):
#         @x   → "The deployment failed because the test suite was not executed prior to release."
#         @@x  → "The deployment failed due to the tests not being executed prior to release."  (≈ @x)
#     ~ (summarise) — SATURATES (fixed after 1):
#         ~x   → "The deployment failed because tests were skipped."
#         ~~x  → "The deployment failed due to skipped tests."                 (≈ ~x, my #43)
#
# The reason is what each operator DOES to its own output. `!` flips polarity, and flipping a
# flip returns you to the start — so it oscillates with period 2 (an involution). `@` moves the
# text to the formal register; once it's THERE, formalising again has nothing to do — it's a
# fixed point. Same for `~`: the summary of a summary is already as distilled as it gets. So:
# POLARITY oscillates, REGISTER and ESSENCE settle. This unifies my #25 (involution `!!x=x`) and
# #43 (kernel `~~x≈~x`) with the new `@@x≈@x` into one law — and it's WHY `@`/`~` are safe to
# over-apply in a train but `!` must be counted (odd vs even matters).
#
# Run:  ./examples/golf-aur1-109-dynamics.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
C='the deployment failed because someone skipped the tests'

say "OPERATOR DYNAMICS  — repeat an op: ! CYCLES (period 2), @ & ~ SATURATE (fixed after 1)"
echo   "  x   => $C"
echo -n "  !x  => "; "$NLIR" -e "!'$C'"  --quiet | fold -s -w 80 | sed '2,$s/^/         /'
echo -n "  !!x => "; "$NLIR" -e "!!'$C'" --quiet | fold -s -w 80 | sed '2,$s/^/         /'
echo   "        ^ back to x (POLARITY oscillates, period 2)"
echo -n "  @x  => "; "$NLIR" -e "@'$C'"  --quiet | fold -s -w 80 | sed '2,$s/^/         /'
echo -n "  @@x => "; "$NLIR" -e "@@'$C'" --quiet | fold -s -w 80 | sed '2,$s/^/         /'
echo   "        ^ ≈ @x (REGISTER settles — fixed point)"
echo -n "  ~x  => "; "$NLIR" -e "~'$C'"  --quiet | fold -s -w 80 | sed '2,$s/^/         /'
echo -n "  ~~x => "; "$NLIR" -e "~~'$C'" --quiet | fold -s -w 80 | sed '2,$s/^/         /'
echo   "        ^ ≈ ~x (ESSENCE settles — fixed point)"

say "Unifies #25 involution (!!x=x) + #43 kernel (~~x≈~x) + new @@x≈@x: POLARITY oscillates, REGISTER/ESSENCE settle. WHY @/~ are safe to over-apply in a train but ! must be counted (odd vs even)."
