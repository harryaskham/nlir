#!/usr/bin/env bash
# nlir-TARGET-golf · aur1 · #109 — "the exit question" (What's the exit strategy?)
#
# The "what's the exit strategy?" turn — planning the OFF-RAMP before committing: how do we back
# out, wind down, or hand off if this doesn't work or outlives its use? It's the discipline of
# knowing how you'll leave before you enter. A "whats the exit strategy" seed steers `?` to that
# off-ramp frame.
#
#   TARGET (24 chars):    "What's the exit strategy?"
#   NLIR   (26 src chars): 'whats the exit strategy'?
#   REAL OUTPUT (contraction floats): "What is the exit strategy?"
#
#   CLOSENESS: exact frame; "what's"/"what is" floats. The 98th ? framing. Distinct from #84
#   reversibility (can it be undone) and #35 contingency (plan B if it fails): this asks for the
#   planned OFF-RAMP / wind-down before you commit.
#
# Run:  ./examples/target-aur1-109-exit.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "TARGET (24 chars):  What's the exit strategy?"
say "NLIR (26 src chars):  'whats the exit strategy'?"
echo -n "  => "; "$NLIR" -e "'whats the exit strategy'?" --quiet

say "98th ? framing: 'whats the exit strategy' → the planned OFF-RAMP / wind-down before committing (vs #84 reversibility, #35 contingency)."
