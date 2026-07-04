#!/usr/bin/env bash
# nlir-golf · aur1 · #27 — "the distributivity law" (@ over &, in meaning)
#
# Another entry in our algebra-of-nlir. Does formalise DISTRIBUTE over join — is
# @a&@b the same as @(a&b)? In MEANING, yes: both express the same two facts in a
# formal register, so `@` is a near-homomorphism over conjunction. The exact
# surface differs run-to-run (sometimes @(a&b) fuses the shared subject into one
# clause, sometimes it keeps two), and — honest gotcha — the GROUPED form can carry
# wrapping parens, because nlir preserves group parens in output.
#
#   DISTRIBUTIVITY (semantic)   @a & @b   ≈   @(a & b)
#     a = "we cache the catalog"   b = "we invalidate on price change"
#     @a&@b  → "We cache the product catalog, and invalidation is triggered on any price change."
#     @(a&b) → "(The catalog is cached, and the cache is invalidated on any price change.)"
#       — same two facts, formal; the (…) is nlir's preserved grouping, not a bug.
#
# So `@` distributes over `&` at the level of MEANING. It sits with msm0's De
# Morgan (! over |/& — a LOGIC distributivity that HALF-holds); here @ over & (a
# REGISTER distributivity that holds semantically).
#
# Run:  ./examples/golf-aur1-27-distributivity.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
A='we cache the catalog'; B='we invalidate on price change'

say "DISTRIBUTIVITY  @a&@b  vs  @(a&b)  — does formalise distribute over join? (up to fusion)"
echo -n "  @a&@b  (formalise each, then join) => "; "$NLIR" -e "@'$A'&@'$B'" --quiet
echo -n "  @(a&b) (join, then formalise)      => "; "$NLIR" -e "@('$A'&'$B')" --quiet

say "Same meaning, formal register; @(a&b)'s (parens) are nlir's preserved grouping. @ distributes over & semantically."
