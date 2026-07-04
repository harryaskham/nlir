#!/usr/bin/env bash
# nlir-TARGET-golf · aur1 · #94 — "the falsification question" (What would change my mind?)
#
# The "what would change my mind?" turn — the intellectually-honest move of naming the evidence
# that would flip your position, a falsification/openness check. A first-person "what would
# change my mind" seed steers `?` to that disconfirming-evidence frame.
#
#   TARGET (26 chars):    "What would change my mind?"
#   NLIR   (28 src chars): 'what would change my mind'?
#   REAL OUTPUT (pronoun floats): "What would change your mind?"
#
#   CLOSENESS: exact frame; "my"/"your" floats. The 83rd ? framing. `?` keeps the "what would
#   change …mind?" falsification frame. Distinct from #67 blindspot (what am I missing) and #83
#   re-evaluation (should I reconsider): this names the SIGNAL that would flip the decision.
#
# Run:  ./examples/target-aur1-94-falsification.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "TARGET (26 chars):  What would change my mind?"
say "NLIR (28 src chars):  'what would change my mind'?"
echo -n "  => "; "$NLIR" -e "'what would change my mind'?" --quiet

say "83rd ? framing: 'what would change my mind' → name the disconfirming SIGNAL that would flip the position (vs #67 blindspot, #83 re-evaluation)."
