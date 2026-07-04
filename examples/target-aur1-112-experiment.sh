#!/usr/bin/env bash
# nlir-TARGET-golf · aur1 · #112 — "the experiment question" (What's the smallest experiment?)
#
# The "what's the smallest experiment?" turn — the lean-startup reflex: what's the cheapest test
# that would tell us if this is worth pursuing, before we commit real effort? It de-risks by
# probing, not building. A "whats the smallest experiment" seed steers `?` to that lean-test frame.
#
#   TARGET (28 chars):    "What's the smallest experiment?"
#   NLIR   (31 src chars): 'whats the smallest experiment'?
#   REAL OUTPUT (contraction floats): "What is the smallest experiment?"
#
#   CLOSENESS: exact frame; "what's"/"what is" floats. The 101st ? framing. Distinct from #79
#   minimalism (simplest build) and #69 first-step: this asks for the cheapest TEST that
#   validates the idea before committing.
#
# Run:  ./examples/target-aur1-112-experiment.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "TARGET (28 chars):  What's the smallest experiment?"
say "NLIR (31 src chars):  'whats the smallest experiment'?"
echo -n "  => "; "$NLIR" -e "'whats the smallest experiment'?" --quiet

say "101st ? framing: 'whats the smallest experiment' → the cheapest TEST that validates before committing (vs #79 minimalism, #69 first-step)."
