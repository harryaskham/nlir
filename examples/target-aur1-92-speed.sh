#!/usr/bin/env bash
# nlir-TARGET-golf · aur1 · #92 — "the speed question" (What's the fastest way to do this?)
#
# The "what's the fastest way to do this?" turn — optimising for TIME/effort, asking for the
# quickest route rather than the best or simplest. A "whats the fastest way to do this" seed
# steers `?` to that speed frame.
#
#   TARGET (~32 chars):   "What's the fastest way to do this?"
#   NLIR   (35 src chars): 'whats the fastest way to do this'?
#   REAL OUTPUT (contraction floats): "What is the fastest way to do this?"
#
#   CLOSENESS: exact frame; "what's"/"what is" floats. The 81st ? framing. `?` keeps the
#   "fastest way?" speed frame. Distinct from #21 best-way (the ideal method) and #85
#   simpler-way (least complex): this optimises purely for SPEED.
#
# Run:  ./examples/target-aur1-92-speed.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "TARGET (~32 chars):  What's the fastest way to do this?"
say "NLIR (35 src chars):  'whats the fastest way to do this'?"
echo -n "  => "; "$NLIR" -e "'whats the fastest way to do this'?" --quiet

say "81st ? framing: 'whats the fastest way' → optimise for SPEED (vs #21 best-way, #85 simpler-way)."
