#!/usr/bin/env bash
# nlir-TARGET-golf · aur1 · #93 — "the quality-bar question" (What does good look like here?)
#
# The "what does good look like here?" turn — asking someone to DEFINE the standard/quality bar
# before starting, so you know what you're aiming at. A "what does good look like here" seed
# steers `?` to that define-the-standard frame.
#
#   TARGET (28 chars):    "What does good look like here?"
#   NLIR   (32 src chars): 'what does good look like here'?
#   REAL OUTPUT:          "What does good look like here?"   (exact)
#
#   CLOSENESS: exact. The 82nd ? framing. `?` keeps the "what does good look like?" quality-bar
#   frame. Distinct from #90 success-signal (how you'll KNOW it works, mid-flight) and #88
#   right-problem: this defines the STANDARD to aim for up front.
#
# Run:  ./examples/target-aur1-93-qualitybar.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "TARGET (28 chars):  What does good look like here?"
say "NLIR (32 src chars):  'what does good look like here'?"
echo -n "  => "; "$NLIR" -e "'what does good look like here'?" --quiet

say "82nd ? framing: 'what does good look like here' → DEFINE the standard/quality bar up front (vs #90 success-signal, #88 right-problem)."
