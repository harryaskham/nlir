#!/usr/bin/env bash
# nlir-TARGET-golf · aur1 · #21 — "the best-practice question"
#
# The recommendation turn: "what's the best way to X?" — you ask when you want the
# idiomatic approach, not just any answer. Seed the task; `?` frames the
# best-practice question.
#
#   TARGET (41 chars):    "What is the best way to handle errors in Rust?"
#   NLIR   (35 src chars): 'best way to handle errors in rust'?
#   REAL OUTPUT:          "What is the best way to handle errors in Rust?"   (exact)
#
#   CLOSENESS: exact. The "best way to …" seed steers `?` to the recommendation
#   frame ("What is the best way …?") and capitalises Rust. A twelfth ? framing
#   beyond the wh-words + yes/no — the "give me the idiomatic approach" question
#   every developer types, from a 35-char seed.
#
# Run:  ./examples/target-aur1-21-bestway.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "TARGET (41 chars):  What is the best way to handle errors in Rust?"
say "NLIR (35 src chars):  'best way to handle errors in rust'?"
echo -n "  => "; "$NLIR" -e "'best way to handle errors in rust'?" --quiet

say "12th ? framing: 'best way to …' = the idiomatic-approach question, from seed wording."
