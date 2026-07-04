#!/usr/bin/env bash
# nlir-TARGET-golf · aur1 · #114 — "the regret question" (What would I regret?)
#
# The "what would I regret?" turn — Bezos's regret-minimization lens: fast-forward and ask which
# choice you'd look back on with regret, then act to avoid THAT. It cuts through short-term noise
# by weighting long-term feeling. A first-person "what would i regret" seed steers `?` to that
# regret-minimization frame.
#
#   TARGET (20 chars):    "What would I regret?"
#   NLIR   (22 src chars): 'what would i regret'?
#   REAL OUTPUT (pronoun floats): "What would you regret?"
#
#   CLOSENESS: exact frame; "I"/"you" floats. The 103rd ? framing. Distinct from #106
#   downside-stakes (cost if it fails) and #98 exit: this weights the DECISION by future regret
#   — the emotional long-game.
#
# Run:  ./examples/target-aur1-114-regret.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "TARGET (20 chars):  What would I regret?"
say "NLIR (22 src chars):  'what would i regret'?"
echo -n "  => "; "$NLIR" -e "'what would i regret'?" --quiet

say "103rd ? framing: 'what would i regret' → Bezos regret-minimization / the emotional long-game (vs #106 downside-stakes, #98 exit)."
