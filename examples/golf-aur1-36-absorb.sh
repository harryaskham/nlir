#!/usr/bin/env bash
# nlir-golf · aur1 · #36 — "the question absorbs polarity" (!x? ≈ x?)
#
# I reached for a "skeptic's challenge": negate a claim, then question it, expecting
# a pointed rebuttal-question. Instead I found a LAW. Questioning a claim absorbs
# its negation: !x? comes back identical to x?. Why? A yes/no question is
# polarity-NEUTRAL — "Should we adopt microservices?" already spans both yes AND
# no, so it doesn't matter whether you asserted the claim or its opposite going in.
# The `?` operator asks ABOUT the polarity axis, so it PROJECTS THAT AXIS OUT.
#
#   ABSORPTION   ! x ? ≈ x ?
#     "we should adopt microservices"    →  x?  "Should we adopt microservices?"
#     "we should adopt microservices"    → !x?  "Should we adopt microservices?"   (same!)
#     "this feature will boost retention"→  x?  "Will this feature boost retention?"
#     "this feature will boost retention"→ !x?  "Will this feature boost retention?" (same!)
#
# In basis terms (msm0's #30): `!` moves the POLARITY axis, but `?` maps an
# assertion to a question ABOUT its polarity — a coordinate that is invariant to
# where you started on that axis. So ? ∘ ! = ?. A satisfying corollary of the
# semantic basis: some operators don't just move axes, they COLLAPSE one.
#
# Run:  ./examples/golf-aur1-36-absorb.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "ABSORPTION  !x? ≈ x?  — questioning a claim absorbs its negation (? projects out polarity)"
for C in 'we should adopt microservices' 'this feature will boost retention'; do
  echo   "  claim: $C"
  echo -n "   x?  => "; "$NLIR" -e "'$C'?"  --quiet
  echo -n "   !x? => "; "$NLIR" -e "!'$C'?" --quiet
done

say "A yes/no question is polarity-neutral, so ? ∘ ! = ?. The question operator collapses the polarity axis."
