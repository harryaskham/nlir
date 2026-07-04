#!/usr/bin/env bash
# nlir-TARGET-golf · aur1 · #100 🎯 MILESTONE — "the meta-reframe question" (What's the real question here?)
#
# The 100th target — fittingly, a question ABOUT questions. The "what's the real question here?"
# turn steps back from the surface debate to name the ACTUAL decision underneath — the reframe
# that dissolves a stuck argument. A "whats the real question here" seed steers `?` to that
# meta / reframe frame.
#
#   TARGET (28 chars):    "What's the real question here?"
#   NLIR   (31 src chars): 'whats the real question here'?
#   REAL OUTPUT (contraction floats): "What's the real question here?"   (exact)
#
#   CLOSENESS: exact. The 89th ? framing, and the 100th target. `?` keeps the "what's the real
#   question?" meta-reframe. Distinct from #88 right-problem (am I solving the right thing) and
#   #85 simpler-way: this asks what we should REALLY be asking — reframes the debate itself.
#
# Run:  ./examples/target-aur1-100-metareframe.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "TARGET (28 chars):  What's the real question here?"
say "NLIR (31 src chars):  'whats the real question here'?"
echo -n "  => "; "$NLIR" -e "'whats the real question here'?" --quiet

say "🎯 89th ? framing / 100th TARGET: 'whats the real question here' → reframe the debate to the ACTUAL question (vs #88 right-problem, #85 simpler-way)."
