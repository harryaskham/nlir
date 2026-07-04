#!/usr/bin/env bash
# nlir-TARGET-golf · aur1 · #81 — "the risk question" (What could go wrong here?) · 70th ? shape
#
# The "what could go wrong here?" turn — the pre-flight risk scan, asking for the failure
# modes of a plan before acting. A "what could go wrong here" seed steers `?` to that
# risk-surfacing frame.
#
#   TARGET (26 chars):    "What could go wrong here?"
#   NLIR   (28 src chars): 'what could go wrong here'?
#   REAL OUTPUT:          "What could go wrong here?"   (exact)
#
#   CLOSENESS: exact. The 70th ? framing — a target milestone. `?` keeps the "what could go
#   wrong?" risk-scan frame. Distinct from #29 consequences (the fallout of an action) and
#   #72 blast-radius (what a change breaks): this asks for the FAILURE MODES up front — the
#   spoken half of #83's pre-mortem.
#
# Run:  ./examples/target-aur1-81-risk.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "TARGET (26 chars):  What could go wrong here?"
say "NLIR (28 src chars):  'what could go wrong here'?"
echo -n "  => "; "$NLIR" -e "'what could go wrong here'?" --quiet

say "70th ? framing (target milestone!): 'what could go wrong here' → the FAILURE MODES (vs #29 consequences, #72 blast-radius)."
