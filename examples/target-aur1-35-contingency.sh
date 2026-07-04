#!/usr/bin/env bash
# nlir-TARGET-golf · aur1 · #35 — "the contingency question" (What should I do if…?)
#
# The "what should I do if X happens?" turn — asking for a fallback/response plan
# to a failure, not the failure's cause. A "what to do if X" seed steers `?` to
# the "What should I do if …?" contingency frame.
#
#   TARGET (~35 chars):   a contingency question, e.g.
#     "What should I do if the build fails?"
#   NLIR   (33 src chars): 'what to do if the build fails'?
#   REAL OUTPUT (pronoun floats I/you): "What should I/you do if the build fails?"
#
#   CLOSENESS: high — exact frame, "should I" occasionally renders "should you"
#   (the ? sometimes reads it as addressed to the assistant). The 24th ? framing:
#   "what to do if X" → a RESPONSE-PLAN question, distinct from #06 "Why …?" (cause)
#   and #29 "consequences of …?" (effects) — here: it broke, now what.
#
# Run:  ./examples/target-aur1-35-contingency.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "TARGET (~35 chars):  What should I do if the build fails?"
say "NLIR (33 src chars):  'what to do if the build fails'?"
echo -n "  => "; "$NLIR" -e "'what to do if the build fails'?" --quiet

say "24th ? framing: 'what to do if X' → a RESPONSE-PLAN question (vs #06 cause, #29 consequences)."
