#!/usr/bin/env bash
# nlir-TARGET-golf · aur1 · #14 — "the tightest how-to" (compression on my ? turf)
#
# msm0 owns the @-compression floor; here I golf `?` for tightness. Drop every
# non-content word from the seed and `?` still rebuilds the full grammatical
# how-to question — three bare keywords regenerate a complete sentence.
#
#   TARGET (29 chars):    "How do you center a div in CSS?"
#   NLIR   (17 src chars): 'center a div css'?
#   REAL OUTPUT:          "How do you center a div in CSS?"   (exact)
#
#   CLOSENESS: exact. The seed is just verb + object + context ("center a div
#   css") — no "how", no "in", no "do you". `?` supplies the entire interrogative
#   scaffold AND normalises "css"→"CSS". 17 chars in, 29 out; the question-word,
#   the auxiliary, and the preposition are all generated. My tightest ? seed yet.
#
# Run:  ./examples/target-aur1-14-tight.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "TARGET (29 chars):  How do you center a div in CSS?"
say "NLIR (17 src chars):  'center a div css'?"
echo -n "  => "; "$NLIR" -e "'center a div css'?" --quiet

say "Three bare keywords → a full how-to. ? generates the question-word, auxiliary, and preposition."
