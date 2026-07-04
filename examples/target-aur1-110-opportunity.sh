#!/usr/bin/env bash
# nlir-TARGET-golf · aur1 · #110 — "the opportunity question" (What's the opportunity here?)
#
# The "what's the opportunity here?" turn — the upside lens: instead of the risk or the cost,
# what could we GAIN, what door does this open? A rare positive-framed probe that reframes a
# problem as a chance. A "whats the opportunity here" seed steers `?` to that upside frame.
#
#   TARGET (26 chars):    "What's the opportunity here?"
#   NLIR   (28 src chars): 'whats the opportunity here'?
#   REAL OUTPUT (contraction floats): "What is the opportunity here?"
#
#   CLOSENESS: exact frame; "what's"/"what is" floats. The 99th ? framing — and a rare UPSIDE
#   one. Distinct from #27 worth-it (net value) and #106 downside-stakes: this looks purely at
#   what could be GAINED / the door it opens.
#
# Run:  ./examples/target-aur1-110-opportunity.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "TARGET (26 chars):  What's the opportunity here?"
say "NLIR (28 src chars):  'whats the opportunity here'?"
echo -n "  => "; "$NLIR" -e "'whats the opportunity here'?" --quiet

say "99th ? framing (a rare UPSIDE one): 'whats the opportunity here' → what could be GAINED / the door it opens (vs #27 worth-it, #106 downside-stakes)."
