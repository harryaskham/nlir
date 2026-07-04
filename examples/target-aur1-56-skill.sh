#!/usr/bin/env bash
# nlir-TARGET-golf · aur1 · #56 — "the skill question" (How do I get better at X?)
#
# The "how do I get better at X?" turn — asking to IMPROVE a skill over time, not do a
# single task. A "how do i get better at X" seed steers `?` to the "How do I get better
# at X?" self-improvement frame.
#
#   TARGET (37 chars):    "How do I get better at code review?"
#   NLIR   (37 src chars): 'how do i get better at code review'?
#   REAL OUTPUT (do/can float): "How can I get better at code review?"
#
#   CLOSENESS: exact frame; "do I"/"can I" floats. The 45th ? framing: "how do i get
#   better at X" asks to build a SKILL — distinct from #01 "how do I X?" (do the task
#   once) and #21 "best way to X?" (the idiomatic method): how to improve at it.
#
# Run:  ./examples/target-aur1-56-skill.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "TARGET (37 chars):  How do I get better at code review?"
say "NLIR (37 src chars):  'how do i get better at code review'?"
echo -n "  => "; "$NLIR" -e "'how do i get better at code review'?" --quiet

say "45th ? framing: 'how do i get better at X' → build a SKILL over time (vs #01 do-a-task, #21 best-way)."
