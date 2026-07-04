#!/usr/bin/env bash
# nlir-TARGET-golf · aur1 · #91 — "the goal-clarity question" (What am I optimizing for?) · 80th ? shape
#
# The "what am I optimizing for?" turn — the step back to name the actual objective before
# tuning anything, a define-the-goal check. A first-person "what am i optimizing for" seed
# steers `?` to that objective-naming frame.
#
#   TARGET (24 chars):    "What am I optimizing for?"
#   NLIR   (26 src chars): 'what am i optimizing for'?
#   REAL OUTPUT (pronoun floats): "What are you optimizing for?"
#
#   CLOSENESS: exact frame; "am I"/"are you" floats. The 80th ? framing — a target milestone.
#   `?` keeps the "optimizing for?" objective frame. Distinct from #88 right-problem (is the
#   target right) and #87 focus (where to look): this names the METRIC you're maximising.
#
# Run:  ./examples/target-aur1-91-goalclarity.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "TARGET (24 chars):  What am I optimizing for?"
say "NLIR (26 src chars):  'what am i optimizing for'?"
echo -n "  => "; "$NLIR" -e "'what am i optimizing for'?" --quiet

say "80th ? framing (target milestone!): 'what am i optimizing for' → name the OBJECTIVE/metric (vs #88 right-problem, #87 focus)."
