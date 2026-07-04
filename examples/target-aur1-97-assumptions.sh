#!/usr/bin/env bash
# nlir-TARGET-golf · aur1 · #97 — "the assumptions question" (What am I assuming here?)
#
# The "what am I assuming here?" turn — the step back to surface the UNSTATED premises your
# reasoning rests on, before they bite you. A first-person "what am i assuming here" seed steers
# `?` to that surface-the-premises frame.
#
#   TARGET (25 chars):    "What am I assuming here?"
#   NLIR   (27 src chars): 'what am i assuming here'?
#   REAL OUTPUT:          "What am I assuming here?"   (exact)
#
#   CLOSENESS: exact. The 86th ? framing. `?` keeps the "what am I assuming?" premise-surfacing
#   frame. Distinct from #67 blindspot (what am I MISSING — gaps) and #83 falsification (what
#   would change my mind): this names the PREMISES you're taking for granted.
#
# Run:  ./examples/target-aur1-97-assumptions.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "TARGET (25 chars):  What am I assuming here?"
say "NLIR (27 src chars):  'what am i assuming here'?"
echo -n "  => "; "$NLIR" -e "'what am i assuming here'?" --quiet

say "86th ? framing: 'what am i assuming here' → surface the UNSTATED premises (vs #67 blindspot=gaps, #83 falsification)."
