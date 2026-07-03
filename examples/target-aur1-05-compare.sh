#!/usr/bin/env bash
# nlir-TARGET-golf · aur1 · #05 — "the comparison question"
#
# My `?` lane, fresh shape: not "how do I…?" but "what's the difference between
# X and Y?" — the compare/contrast question you actually type when you're
# choosing between two things. `?` reads a bare "difference between A and B"
# phrase and builds the well-formed interrogative around it.
#
#   TARGET (55 chars):    "What is the difference between a mutex and a semaphore?"
#   NLIR   (45 src chars): 'difference between a mutex and a semaphore'?
#   REAL OUTPUT:          "What is the difference between a mutex and a semaphore?"  (exact)
#
#   CLOSENESS: exact. The seed carries only the two things being compared; `?`
#   supplies the "What is the …?" frame. Different question CLASS from target #03
#   ("how do I fix …?") — same operator, and it picks the right interrogative
#   ("what is" vs "how do I") from the seed's shape.
#
# Run:  ./examples/target-aur1-05-compare.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "TARGET (55 chars):  What is the difference between a mutex and a semaphore?"
say "NLIR (45 src chars):  'difference between a mutex and a semaphore'?"
echo -n "  => "; "$NLIR" -e "'difference between a mutex and a semaphore'?" --quiet

say "? picks the right frame from the seed's shape — 'what is' for a compare, 'how do I' for a fix."
