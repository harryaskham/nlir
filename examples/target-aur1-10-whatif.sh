#!/usr/bin/env bash
# nlir-TARGET-golf · aur1 · #10 — "the what-if question" (& ∘ ?)
#
# Combo lane: bundle two actions with `&`, then question the bundle with `?` —
# and `?` reads the imperative shape and reaches for the HYPOTHETICAL "what if…?"
# frame, giving you a single brainstorming question over multiple moves.
#
#   TARGET (~48 chars):  a compound request over two actions, e.g.
#     "Could you add error handling and write tests?"  /  "What if you added
#      error handling and wrote tests?"
#   NLIR   (37 src chars): ('add error handling'&'write tests')?
#   REAL OUTPUT (framing floats run-to-run):
#     "Could you add error handling and write tests?"
#     "What if you added error handling and wrote tests?"
#
#   HOW IT NESTS: &[…] joins the two task stems into "add error handling and write
#   tests"; the postfix `?` then wraps the whole conjunction in an interrogative,
#   floating between a polite request ("Could you …?") and a hypothetical ("What
#   if you …?"). Two ops turn a pair of raw actions into one well-formed
#   suggestion-question — the "have you considered doing X and Y" pi turn.
#
# Run:  ./examples/target-aur1-10-whatif.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "TARGET (~48 chars):  a compound request — Could you add error handling and write tests?  (or 'What if you added…')"
say "NLIR (37 src chars):  ('add error handling'&'write tests')?   —  ? ∘ &"
echo -n "  => "; "$NLIR" -e "('add error handling'&'write tests')?" --quiet

say "& bundles the actions, ? wraps them in a 'what if…?' — a compound suggestion-question."
