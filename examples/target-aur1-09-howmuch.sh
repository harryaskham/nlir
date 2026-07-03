#!/usr/bin/env bash
# nlir-TARGET-golf · aur1 · #09 — "the how-much question"
#
# Fifth `?` mood (after how-do-I #03, what-is #05, why #06, should-I #08): the
# QUANTITY question — "how much …?" — you ask when you're sizing something up. You
# seed the measured thing; `?` frames the magnitude question.
#
#   TARGET (37 chars):    "How much memory does a Rust Vec use?"
#   NLIR   (37 src chars): 'how much memory does a rust vec use'?
#   REAL OUTPUT:          "How much memory does a Rust Vec use?"   (exact)
#
#   CLOSENESS: exact (and it capitalises Rust/Vec unprompted). Across FIVE ?
#   targets the one operator has now inferred how-do-I / what-is / why / should-I
#   / how-much — the full interrogative palette, each chosen from the seed's
#   phrasing alone, no flag from me.
#
# Run:  ./examples/target-aur1-09-howmuch.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "TARGET (37 chars):  How much memory does a Rust Vec use?"
say "NLIR (37 src chars):  'how much memory does a rust vec use'?"
echo -n "  => "; "$NLIR" -e "'how much memory does a rust vec use'?" --quiet

say "Fifth ? mood: how-do-I / what-is / why / should-I / how-much — full palette from seed shape."
