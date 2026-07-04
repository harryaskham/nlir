#!/usr/bin/env bash
# nlir-TARGET-golf · aur1 · #80 — "the testing question" (How do I test this properly?)
#
# The "how do I test this properly?" turn — asking for the right verification approach, a
# quality/testing ask. A "how do i test this properly" seed steers `?` to the "proper way to
# test this?" verification frame.
#
#   TARGET (30 chars):    "How do I test this properly?"
#   NLIR   (32 src chars): 'how do i test this properly'?
#   REAL OUTPUT (rephrases): "What is the proper way to test this?"
#
#   CLOSENESS: exact intent; `?` rephrases "how do I test this properly" as "what is the
#   proper way to test this" (same question). The 69th ? framing: verification APPROACH —
#   distinct from #74 does-this-scale (a property to check) and #01 how-do-I (do the task):
#   this asks how to VERIFY it correctly.
#
# Run:  ./examples/target-aur1-80-testing.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "TARGET (30 chars):  How do I test this properly?"
say "NLIR (32 src chars):  'how do i test this properly'?"
echo -n "  => "; "$NLIR" -e "'how do i test this properly'?" --quiet

say "69th ? framing: 'how do i test this properly' → the verification APPROACH (vs #74 does-this-scale, #01 how-do-I)."
