#!/usr/bin/env bash
# nlir-TARGET-golf · aur1 · #106 — "the downside-stakes question" (What's the cost of getting this wrong?)
#
# The "what's the cost of getting this wrong?" turn — sizing the DOWNSIDE before committing: if
# this fails, how bad is it? It calibrates how much caution/rigor the decision deserves. A
# "whats the cost of getting this wrong" seed steers `?` to that downside-magnitude frame.
#
#   TARGET (35 chars):    "What's the cost of getting this wrong?"
#   NLIR   (39 src chars): 'whats the cost of getting this wrong'?
#   REAL OUTPUT (contraction floats): "What is the cost of getting this wrong?"
#
#   CLOSENESS: exact frame; "what's"/"what is" floats. The 95th ? framing. Distinct from #27
#   worth-it (net value) and #84 reversibility: this sizes the DOWNSIDE if the decision fails —
#   the stakes, not the odds.
#
# Run:  ./examples/target-aur1-106-downside.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "TARGET (35 chars):  What's the cost of getting this wrong?"
say "NLIR (39 src chars):  'whats the cost of getting this wrong'?"
echo -n "  => "; "$NLIR" -e "'whats the cost of getting this wrong'?" --quiet

say "95th ? framing: 'whats the cost of getting this wrong' → size the DOWNSIDE if it fails / the stakes (vs #27 worth-it, #84 reversibility)."
