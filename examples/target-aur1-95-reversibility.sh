#!/usr/bin/env bash
# nlir-TARGET-golf · aur1 · #95 — "the reversibility question" (Is this a one-way door?)
#
# The "is this a one-way door?" turn — the Bezos framing: is this decision REVERSIBLE (walk
# back through the door) or irreversible (one-way)? It sets how much caution the call deserves.
# A "is this a one way door" seed steers `?` to that reversibility frame.
#
#   TARGET (24 chars):    "Is this a one-way door?"
#   NLIR   (26 src chars): 'is this a one way door'?
#   REAL OUTPUT:          "Is this a one way door?"   (exact; hyphen floats)
#
#   CLOSENESS: exact frame. The 84th ? framing. `?` keeps the "one-way door?" reversibility
#   metaphor. Distinct from #81 risk (what could go wrong) and #72 blast-radius (how far damage
#   spreads): this asks specifically whether the decision can be UNDONE.
#
# Run:  ./examples/target-aur1-95-reversibility.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "TARGET (24 chars):  Is this a one-way door?"
say "NLIR (26 src chars):  'is this a one way door'?"
echo -n "  => "; "$NLIR" -e "'is this a one way door'?" --quiet

say "84th ? framing: 'is this a one way door' → is the decision REVERSIBLE (Bezos framing) vs #81 risk, #72 blast-radius."
