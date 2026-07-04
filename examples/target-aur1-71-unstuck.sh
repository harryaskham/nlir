#!/usr/bin/env bash
# nlir-TARGET-golf · aur1 · #71 — "the unstuck question" (How do I get unstuck on this?) · 60th ? shape
#
# The "how do I get unstuck on this?" turn — asking to break a stall / regain momentum when
# you're blocked, not to fix a fault or take a first step from zero. A "how do i get unstuck
# on this" seed steers `?` to the "How do I get unstuck on this?" momentum frame.
#
#   TARGET (32 chars):    "How do I get unstuck on this?"
#   NLIR   (33 src chars): 'how do i get unstuck on this'?
#   REAL OUTPUT:          "How do I get unstuck on this?"   (exact)
#
#   CLOSENESS: exact. The 60th ? framing — a target milestone. `?` keeps the "get unstuck?"
#   momentum frame. Distinct from #69 first-step (starting from zero) and #60 recovery (after
#   a failure): this is being MID-WAY and blocked — how to break the stall and move again.
#
# Run:  ./examples/target-aur1-71-unstuck.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "TARGET (32 chars):  How do I get unstuck on this?"
say "NLIR (33 src chars):  'how do i get unstuck on this'?"
echo -n "  => "; "$NLIR" -e "'how do i get unstuck on this'?" --quiet

say "60th ? framing (target milestone!): 'how do i get unstuck' → break a STALL (vs #69 first-step, #60 recovery)."
