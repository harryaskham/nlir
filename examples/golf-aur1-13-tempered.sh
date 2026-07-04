#!/usr/bin/env bash
# nlir-golf · aur1 · #13 — "the tempered take" (self-critique)
#
# Intellectual honesty in one expression: state a bold claim, fold in the
# STRONGEST case against it, and summarise — you get back the mature, self-aware
# position, not the hot take.
#
#   TEMPERED TAKE   ~(x & >@!x)
#     x       your bold claim
#     >@!x    expand ∘ formalise ∘ negate  = the fullest, most authoritative
#             counterargument (the steelman of the OPPOSITE, cf. #08 / #12)
#     &       hold the claim and its best objection together
#     ~       distil the pair into the wiser, tempered conclusion
#
# Give it "we should rewrite the whole codebase in Rust" and it comes back with
# the grown-up version: "argues against a full rewrite, favoring incremental
# adoption in new or performance-critical areas." The bold claim meets its best
# objection and emerges wiser — a devil's-advocate you apply to YOURSELF.
#
# Run:  ./examples/golf-aur1-13-tempered.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
C='we should rewrite the whole codebase in rust'

say "TEMPERED TAKE  ~(x & >@!x)  — claim + its strongest counterargument, distilled to the wiser take"
echo "  bold claim: $C"
echo -n "  => "
"$NLIR" -e "~('$C'&>@!'$C')" --quiet

say "x holds the claim, >@!x builds the best objection, ~ lands the mature position — self-critique."
