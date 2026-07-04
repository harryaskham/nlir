#!/usr/bin/env bash
# nlir-TARGET-golf · aur1 · #48 — "the persuasion question" (How do I convince X to Y?)
#
# The "how do I convince X to Y?" turn — asking for a strategy to win someone over,
# not how to do the thing itself. A "how do i convince X to Y" seed steers `?` to the
# "How do I convince X to Y?" persuasion frame.
#
#   TARGET (39 chars):    "How do I convince my team to adopt TDD?"
#   NLIR   (38 src chars): 'how do i convince my team to adopt tdd'?
#   REAL OUTPUT (I/can float): "How can I convince my team to adopt TDD?"
#
#   CLOSENESS: exact frame; capitalises the acronym; "do I"/"can I" floats run-to-run.
#   The 37th ? framing: "how do i convince X to Y" asks for a PERSUASION strategy —
#   distinct from #01 "how do I X?" (do the task) and #34 "what's the point of X?"
#   (the rationale): here, how to bring OTHER PEOPLE around.
#
# Run:  ./examples/target-aur1-48-persuasion.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "TARGET (39 chars):  How do I convince my team to adopt TDD?"
say "NLIR (38 src chars):  'how do i convince my team to adopt tdd'?"
echo -n "  => "; "$NLIR" -e "'how do i convince my team to adopt tdd'?" --quiet

say "37th ? framing: 'how do i convince X to Y' → a PERSUASION strategy (vs #01 do-the-task, #34 rationale)."
