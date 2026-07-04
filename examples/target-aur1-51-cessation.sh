#!/usr/bin/env bash
# nlir-TARGET-golf · aur1 · #51 — "the cessation question" (How do I stop X-ing?)
#
# The "how do I stop X happening?" turn — asking to END a recurring problem, not to
# do or avoid a one-off. A "how do i stop getting X" seed steers `?` to the "How do I
# stop getting X?" cessation frame.
#
#   TARGET (~38 chars):   "How do I stop getting merge conflicts?"
#   NLIR   (37 src chars): 'how do i stop getting merge conflicts'?
#   REAL OUTPUT (do/can float): "How can I stop getting merge conflicts?"
#
#   CLOSENESS: exact frame; "do I"/"can I" floats run-to-run. The 40th ? framing:
#   "how do i stop getting X" asks to END a RECURRING problem — distinct from #01 "how
#   do I X?" (do a task) and #45's whats-causing (diagnose): make it stop happening.
#
# Run:  ./examples/target-aur1-51-cessation.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "TARGET (~38 chars):  How do I stop getting merge conflicts?"
say "NLIR (37 src chars):  'how do i stop getting merge conflicts'?"
echo -n "  => "; "$NLIR" -e "'how do i stop getting merge conflicts'?" --quiet

say "40th ? framing: 'how do i stop getting X' → END a recurring problem (vs #01 do-a-task, #45 diagnose)."
