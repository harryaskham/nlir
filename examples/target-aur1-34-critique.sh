#!/usr/bin/env bash
# nlir-TARGET-golf · aur1 · #34 — "the critique question" (What's wrong with…?)
#
# The "what's wrong with X?" turn — asking for a critique/flaw-finding pass, not a
# definition or a how-to. A "whats wrong with X" seed steers `?` to the "What is
# wrong with …?" critique frame.
#
#   TARGET (34 chars):    "What's wrong with this approach?"
#   NLIR   (34 src chars): 'whats wrong with this approach'?
#   REAL OUTPUT:          "What is wrong with this approach?"   (≈ exact; expands whats→what is)
#
#   CLOSENESS: exact meaning; `?` normalises the contraction "whats" → "What is"
#   and adds the mark. The 23rd ? framing: "what's wrong with" asks for a CRITIQUE
#   (find the flaws), distinct from #02 "What is X?" (definition) and #06 "Why …?"
#   (cause) — the review-my-work turn.
#
# Run:  ./examples/target-aur1-34-critique.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "TARGET (34 chars):  What's wrong with this approach?"
say "NLIR (34 src chars):  'whats wrong with this approach'?"
echo -n "  => "; "$NLIR" -e "'whats wrong with this approach'?" --quiet

say "23rd ? framing: 'whats wrong with X' → a CRITIQUE question (vs #02 definition, #06 cause)."
