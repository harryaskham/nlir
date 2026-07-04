#!/usr/bin/env bash
# nlir-TARGET-golf · aur1 · #61 — "the lateness question" (Is it too late to X?) · 50th ? shape
#
# The "is it too late to X?" turn — asking whether a window to act has already closed, a
# timing/regret check. A "is it too late to X" seed steers `?` to the "Is it too late to
# X?" window frame.
#
#   TARGET (34 chars):    "Is it too late to switch frameworks?"
#   NLIR   (37 src chars): 'is it too late to switch frameworks'?
#   REAL OUTPUT:          "Is it too late to switch frameworks?"   (exact)
#
#   CLOSENESS: exact. The 50th ? framing — a target milestone. `?` keeps the "is it too
#   late to …?" window frame. Distinct from #08 "should I …?" (advisability) and #11
#   "when …?" (scheduling): this asks whether the moment to act has already PASSED.
#
# Run:  ./examples/target-aur1-61-lateness.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "TARGET (34 chars):  Is it too late to switch frameworks?"
say "NLIR (37 src chars):  'is it too late to switch frameworks'?"
echo -n "  => "; "$NLIR" -e "'is it too late to switch frameworks'?" --quiet

say "50th ? framing (target milestone!): 'is it too late to X' → has the WINDOW closed (vs #08 should-I, #11 when)."
