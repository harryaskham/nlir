#!/usr/bin/env bash
# nlir-TARGET-golf · aur1 · #117 — "the evidence question" (What does the data say?)
#
# The "what does the data say?" turn — the empiricist's redirect: away from opinion and intuition,
# toward what the measurements actually show. It grounds a debate in evidence rather than the
# loudest voice. A "what does the data say" seed steers `?` to that evidence frame.
#
#   TARGET (22 chars):    "What does the data say?"
#   NLIR   (24 src chars): 'what does the data say'?
#   REAL OUTPUT:          "What does the data say?"   (exact)
#
#   CLOSENESS: exact. The 106th ? framing. `?` keeps the "what does the data say?" evidence frame.
#   Distinct from #93 measurement (how to measure) and #113 Occam: this asks what the EXISTING
#   evidence actually shows — ground the argument in data.
#
# Run:  ./examples/target-aur1-117-evidence.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "TARGET (22 chars):  What does the data say?"
say "NLIR (24 src chars):  'what does the data say'?"
echo -n "  => "; "$NLIR" -e "'what does the data say'?" --quiet

say "106th ? framing: 'what does the data say' → ground the argument in EVIDENCE, not opinion (vs #93 measurement, #113 Occam)."
