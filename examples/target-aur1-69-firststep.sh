#!/usr/bin/env bash
# nlir-TARGET-golf · aur1 · #69 — "the first-step question" (What's the smallest first step I can take?)
#
# The "what's the smallest first step I can take?" turn — asking for the tiniest concrete
# action to get unstuck, a momentum/first-move ask. A first-person "whats the smallest first
# step i can take" seed steers `?` to the "What's the smallest first step you can take?" frame.
#
#   TARGET (~40 chars):   "What's the smallest first step I can take?"
#   NLIR   (43 src chars): 'whats the smallest first step i can take'?
#   REAL OUTPUT (pronoun+contraction float): "What is the smallest first step you can take?"
#
#   CLOSENESS: exact frame; "what's"/"what is" and "I"/"you" float. The 58th ? framing:
#   "whats the smallest first step" asks for the MINIMAL next action — distinct from #35
#   getting-started (the on-ramp) and #21 best-way (the ideal method): just get moving.
#
# Run:  ./examples/target-aur1-69-firststep.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "TARGET (~40 chars):  What's the smallest first step I can take?"
say "NLIR (43 src chars):  'whats the smallest first step i can take'?"
echo -n "  => "; "$NLIR" -e "'whats the smallest first step i can take'?" --quiet

say "58th ? framing: 'whats the smallest first step' → the MINIMAL next action (vs #35 getting-started, #21 best-way)."
