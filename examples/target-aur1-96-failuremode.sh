#!/usr/bin/env bash
# nlir-TARGET-golf · aur1 · #96 — "the failure-mode question" (What breaks first?)
#
# The "what breaks first?" turn — the stress-test move: under load or change, which part gives
# way SOONEST? It finds the bottleneck / weakest link before it finds you. A "what breaks first"
# seed steers `?` to that failure-mode frame.
#
#   TARGET (17 chars):    "What breaks first?"
#   NLIR   (19 src chars): 'what breaks first'?
#   REAL OUTPUT:          "What breaks first?"   (exact)
#
#   CLOSENESS: exact. The 85th ? framing. `?` keeps the "what breaks first?" failure-mode frame.
#   Distinct from #74 does-this-scale (a yes/no property) and #72 blast-radius (how far damage
#   spreads): this asks WHICH component fails soonest — the bottleneck.
#
# Run:  ./examples/target-aur1-96-failuremode.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "TARGET (17 chars):  What breaks first?"
say "NLIR (19 src chars):  'what breaks first'?"
echo -n "  => "; "$NLIR" -e "'what breaks first'?" --quiet

say "85th ? framing: 'what breaks first' → the failure-mode / weakest link under stress (vs #74 does-this-scale, #72 blast-radius)."
