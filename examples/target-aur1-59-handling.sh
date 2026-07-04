#!/usr/bin/env bash
# nlir-TARGET-golf · aur1 · #59 — "the handling question" (How do I handle X?)
#
# The "how do I handle X?" turn — asking how to DEAL WITH a tricky situation, softer and
# more interpersonal than a how-to task. A "how do i handle X" seed steers `?` to the
# "How do I handle X?" coping frame.
#
#   TARGET (~38 chars):   "How do I handle a difficult code review?"
#   NLIR   (38 src chars): 'how do i handle a difficult code review'?
#   REAL OUTPUT (do/you float): "How do you handle a difficult code review?"
#
#   CLOSENESS: exact frame; "do I"/"do you" floats. The 48th ? framing: "how do i handle
#   X" asks how to NAVIGATE a situation — distinct from #01 "how do I X?" (execute a task)
#   and #34's what-to-do-if (contingency): dealing with something awkward or hard.
#
# Run:  ./examples/target-aur1-59-handling.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "TARGET (~38 chars):  How do I handle a difficult code review?"
say "NLIR (38 src chars):  'how do i handle a difficult code review'?"
echo -n "  => "; "$NLIR" -e "'how do i handle a difficult code review'?" --quiet

say "48th ? framing: 'how do i handle X' → NAVIGATE a situation (vs #01 execute-a-task, #34 contingency)."
