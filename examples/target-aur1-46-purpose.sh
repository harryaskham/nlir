#!/usr/bin/env bash
# nlir-TARGET-golf · aur1 · #46 — "the purpose question" (What's the point of X?)
#
# The "what's the point of X?" turn — asking for the RATIONALE/value of a practice,
# often mildly skeptical, not its mechanism. A "whats the point of X" seed steers `?`
# to the "What is the point of X?" purpose frame.
#
#   TARGET (31 chars):    "What's the point of code review?"
#   NLIR   (31 src chars): 'whats the point of code review'?
#   REAL OUTPUT:          "What is the point of code review?"   (≈ exact; whats→what is)
#
#   CLOSENESS: exact meaning; `?` normalises "whats" → "What is" and adds the mark.
#   The 35th ? framing: "what's the point of X" asks for the PURPOSE/justification of a
#   practice — distinct from #06 "Why …?" (cause of an event) and #18's how-does-work
#   (mechanism): why-do-we-even-bother-with-this.
#
# Run:  ./examples/target-aur1-46-purpose.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "TARGET (31 chars):  What's the point of code review?"
say "NLIR (31 src chars):  'whats the point of code review'?"
echo -n "  => "; "$NLIR" -e "'whats the point of code review'?" --quiet

say "35th ? framing: 'whats the point of X' → PURPOSE/justification (vs #06 cause, #18 mechanism)."
