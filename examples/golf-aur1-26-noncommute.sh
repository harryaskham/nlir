#!/usr/bin/env bash
# nlir-golf · aur1 · #26 — "the non-commutativity law" (order matters)
#
# Next entry in the operator-algebra series. Composition does NOT commute: `@:x`
# and `:@x` use the same two operators but land in opposite registers, because the
# OUTERMOST (last-applied) op wins.
#
#   NON-COMMUTATIVITY   @:x  ≠  :@x
#     @:x  = formalise(simplify(x))  → simplify first, formalise last ⇒ ends FORMAL
#     :@x  = simplify(formalise(x))  → formalise first, simplify last ⇒ ends SIMPLE
#
# Same fact — "the API returns a 429 when you exceed the rate limit":
#     @:x → "If the website receives an excessive number of requests… it returns a
#            rate-limiting notification and temporarily suspends responses."  (formal)
#     :@x → "The website says 'slow down!' if you ask it for too many things too fast." (plain)
# The inner op sets the starting point; the outer op sets the destination. A law
# to sit beside ! (involution, #25), @ (saturation, #23), ~ (intensification, #05):
# whether ops commute is part of nlir's algebra.
#
# Run:  ./examples/golf-aur1-26-noncommute.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
S='the API returns a 429 when you exceed the rate limit'

say "NON-COMMUTATIVITY  @:x vs :@x  — same two ops, opposite registers; the OUTER op wins"
echo "  x: $S"
echo -n "  @:x (last op @, ends FORMAL) => "; "$NLIR" -e "@:'$S'" --quiet
echo -n "  :@x (last op :, ends SIMPLE) => "; "$NLIR" -e ":@'$S'" --quiet

say "Inner op = start, outer op = destination. Order matters — non-commutativity is part of the algebra."
