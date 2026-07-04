#!/usr/bin/env bash
# nlir-TARGET-golf · aur1 · #43 — "the cause-diagnosis question" (What's causing X?)
#
# The "what's causing X?" turn — asking for the root cause of a SPECIFIC observed
# symptom, not a general "why". A "whats causing X" seed steers `?` to the "What
# is causing X?" diagnosis frame.
#
#   TARGET (32 chars):    "What's causing the slow queries?"
#   NLIR   (32 src chars): 'whats causing the slow queries'?
#   REAL OUTPUT:          "What is causing the slow queries?"   (≈ exact; expands whats→what is)
#
#   CLOSENESS: exact meaning; `?` normalises "whats" → "What is" and adds the mark.
#   The 32nd ? framing: "what's causing X" points at a concrete SYMPTOM and asks for
#   its cause — distinct from #06 "Why …?" (general reason) and #34 "What's wrong
#   with X?" (critique of an artifact) — here: diagnose this specific problem.
#
# Run:  ./examples/target-aur1-43-diagnosis.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "TARGET (32 chars):  What's causing the slow queries?"
say "NLIR (32 src chars):  'whats causing the slow queries'?"
echo -n "  => "; "$NLIR" -e "'whats causing the slow queries'?" --quiet

say "32nd ? framing: 'whats causing X' → root-cause of a SYMPTOM (vs #06 general why, #34 critique)."
