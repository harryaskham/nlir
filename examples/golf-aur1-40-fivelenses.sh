#!/usr/bin/env bash
# nlir-golf · aur1 · #40 — "the five lenses" (one claim, seen five ways) · MILESTONE
#
# Forty examples in, a showcase: point five different operators at a SINGLE claim
# and watch it refract into five independent views. This is msm0's semantic basis
# made concrete — each sigil moves a different axis, so from one point in meaning
# you can look along five orthogonal directions at once.
#
#   FIVE LENSES on "we should cache the product catalog in redis":
#     #x  (topic)    → "Product catalog caching in Redis"          — what it's ABOUT
#     ~x  (gist)     → "Cache the product catalog in Redis."       — the essence
#     !x  (counter)  → "we should not cache the product catalog…"  — the opposite
#     x?  (question) → "Should we cache the product catalog in Redis?" — interrogated
#     @x  (formal)   → "We should cache the product catalog in Redis." — dressed up
#
# Topic, gist, counter, question, register — five lenses, one statement, no lens
# reachable from another (they're independent axes, #30/#31). It's the whole
# cognitive toolkit in one line: the subject to file it, the summary to grasp it,
# the negation to challenge it, the question to probe it, the register to send it.
#
# Run:  ./examples/golf-aur1-40-fivelenses.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
C='we should cache the product catalog in redis'

say "FIVE LENSES  #x / ~x / !x / x? / @x  — one claim refracted into five independent views"
echo   "  claim: $C"
echo -n "  #x  (topic)    => "; "$NLIR" -e "#'$C'" --quiet
echo -n "  ~x  (gist)     => "; "$NLIR" -e "~'$C'" --quiet
echo -n "  !x  (counter)  => "; "$NLIR" -e "!'$C'" --quiet
echo -n "  x?  (question) => "; "$NLIR" -e "'$C'?" --quiet
echo -n "  @x  (formal)   => "; "$NLIR" -e "@'$C'" --quiet

say "Five sigils, five orthogonal axes — the semantic basis (#30) made concrete. The whole toolkit, one line."
