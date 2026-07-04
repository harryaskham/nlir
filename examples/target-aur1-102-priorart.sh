#!/usr/bin/env bash
# nlir-TARGET-golf · aur1 · #102 — "the prior-art question" (Who else has solved this?)
#
# The "who else has solved this?" turn — the instinct to look for existing solutions / prior art
# before reinventing, learning from who's already walked the path. A "who else has solved this"
# seed steers `?` to that prior-art frame.
#
#   TARGET (23 chars):    "Who else has solved this?"
#   NLIR   (25 src chars): 'who else has solved this'?
#   REAL OUTPUT:          "Who else has solved this?"   (exact)
#
#   CLOSENESS: exact. The 91st ? framing. `?` keeps the "who else has solved this?" prior-art
#   frame. Distinct from #75 shared-experience (has anyone hit this) and #84 redundancy: this
#   looks for EXISTING solutions to learn from before building your own.
#
# Run:  ./examples/target-aur1-102-priorart.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "TARGET (23 chars):  Who else has solved this?"
say "NLIR (25 src chars):  'who else has solved this'?"
echo -n "  => "; "$NLIR" -e "'who else has solved this'?" --quiet

say "91st ? framing: 'who else has solved this' → prior art / existing solutions to learn from (vs #75 shared-experience, #84 redundancy)."
