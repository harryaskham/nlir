#!/usr/bin/env bash
# nlir-TARGET-golf · aur1 · #16 — "the polite compound request-question" (@ ∘ ?)
#
# The most natural pi ask: a courteous request that bundles two things and ends
# as a question. `?` builds the interrogative over an and-joined pair; `@`
# wraps it in politeness — you seed the two raw actions, the manners are generated.
#
#   TARGET (58 chars):
#     "Could you please review the pull request and confirm that the tests pass?"
#   NLIR (41 src chars):
#     @('review the PR and confirm the tests pass'?)
#   REAL OUTPUT:
#     "Could you please review the pull request and confirm that the tests pass?"  (exact)
#
#   HOW IT NESTS: the inner '…'? turns the two-part imperative into a question
#   ("…review the PR and confirm the tests pass?"); the outer @ lifts it to
#   "Could you please …?", expands PR→pull request, and smooths the grammar. Two
#   ops reconstruct a polished, polite, compound ask from a 41-char seed.
#
# Run:  ./examples/target-aur1-16-request.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "TARGET (58 chars):  Could you please review the pull request and confirm that the tests pass?"
say "NLIR (41 src chars):  @('review the PR and confirm the tests pass'?)"
echo -n "  => "; "$NLIR" -e "@('review the PR and confirm the tests pass'?)" --quiet

say "Inner ? questions the two-part imperative, outer @ makes it polite — a compound ask from 41c."
