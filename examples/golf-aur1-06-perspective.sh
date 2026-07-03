#!/usr/bin/env bash
# nlir-golf · aur1 · #06 — "perspective-shift"
#
# Composing DIFFERENT operators changes the VOICE and STANCE of a claim, not just
# its length. Two fresh moves:
#
#   DEVIL'S ADVOCATE   @!x      (4 sigils)   formalise( negate( x ) )
#     !x flips the claim to its opposite; @ then dresses that opposite in
#     confident, professional language → a credible counter-argument you can
#     actually put in a doc. "we should ship on friday" → a polished "we
#     recommend against deploying on Friday."
#
#   TWO-AUDIENCE SPECTRUM   [:c , @c]        one fact, two registers, side by side
#     :c simplifies to plain language (explain-like-I'm-5);
#     @c formalises to precise technical prose (for the spec).
#     The same sentence rendered for a layperson AND an engineer at once.
#
# Perspective is just which operators you stack: ! flips stance, @ raises
# register, : lowers it — compose them to move a claim around the room.
#
# Run:  ./examples/golf-aur1-06-perspective.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "DEVIL'S ADVOCATE  @!x  — formalise(negate(x)) = a polished counter-argument"
echo "  claim: we should ship the release on friday"
echo -n "  => "; "$NLIR" -e "@!'we should ship the release on friday'" --quiet

say "TWO-AUDIENCE SPECTRUM  [:c , @c]  — one fact for a layperson | an engineer"
echo "  fact: the API returns a 429 when you exceed the rate limit"
"$NLIR" -e "[:'the API returns a 429 when you exceed the rate limit',@'the API returns a 429 when you exceed the rate limit']" --quiet

say "Perspective = which operators you stack: ! flips stance, @ raises register, : lowers it."
