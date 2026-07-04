#!/usr/bin/env bash
# nlir-TARGET-golf · aur1 · #103 — "the dependency question" (What would break if I removed this?)
#
# The "what would break if I removed this?" turn — the subtractive probe: pull a piece out (in
# your head) and see what falls over, revealing what actually DEPENDS on it. It's how you find
# hidden coupling and test whether something is load-bearing. A first-person "what would break if
# i removed this" seed steers `?` to that dependency frame.
#
#   TARGET (34 chars):    "What would break if I removed this?"
#   NLIR   (37 src chars): 'what would break if i removed this'?
#   REAL OUTPUT (pronoun floats): "What would break if you removed this?"
#
#   CLOSENESS: exact frame; "I"/"you" floats. The 92nd ? framing. `?` keeps the "what would break
#   if …removed?" dependency frame. Distinct from #33 necessity (do we need it) and #72
#   blast-radius (how far damage spreads): this maps what DEPENDS on the thing via subtraction.
#
# Run:  ./examples/target-aur1-103-dependency.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "TARGET (34 chars):  What would break if I removed this?"
say "NLIR (37 src chars):  'what would break if i removed this'?"
echo -n "  => "; "$NLIR" -e "'what would break if i removed this'?" --quiet

say "92nd ? framing: 'what would break if i removed this' → the subtractive dependency probe / hidden coupling (vs #33 necessity, #72 blast-radius)."
