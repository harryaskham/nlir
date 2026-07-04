#!/usr/bin/env bash
# nlir-TARGET-golf · aur1 · #67 — "the blindspot question" (What am I missing here?)
#
# The "what am I missing here?" turn — asking to surface the thing you can't see, a
# blindspot check. A first-person "what am i missing here" seed steers `?` to the "What am
# I missing here?" gap-finding frame.
#
#   TARGET (24 chars):    "What am I missing here?"
#   NLIR   (26 src chars): 'what am i missing here'?
#   REAL OUTPUT:          "What am I missing here?"   (exact)
#
#   CLOSENESS: exact. The 56th ? framing. `?` keeps the "what am I missing?" blindspot
#   frame. Distinct from #25 whats-wrong (a fault to fix) and #63 catch (a hidden cost of
#   an option): this asks what YOU'VE OVERLOOKED — the gap in your own view.
#
# Run:  ./examples/target-aur1-67-blindspot.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "TARGET (24 chars):  What am I missing here?"
say "NLIR (26 src chars):  'what am i missing here'?"
echo -n "  => "; "$NLIR" -e "'what am i missing here'?" --quiet

say "56th ? framing: 'what am i missing here' → surface a BLINDSPOT (vs #25 whats-wrong, #63 catch)."
