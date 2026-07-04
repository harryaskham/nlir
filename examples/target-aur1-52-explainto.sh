#!/usr/bin/env bash
# nlir-TARGET-golf · aur1 · #52 — "the explain-to question" (How do I explain X to Y?)
#
# The "how do I explain X to Y?" turn — asking how to pitch a concept to a SPECIFIC
# audience, not what it is. A "how do i explain X to Y" seed steers `?` to the "How do
# I explain X to Y?" audience-communication frame.
#
#   TARGET (~39 chars):   "How do I explain OAuth to a designer?"
#   NLIR   (37 src chars): 'how do i explain oauth to a designer'?
#   REAL OUTPUT (do/can float): "How can I explain OAuth to a designer?"
#
#   CLOSENESS: exact frame; capitalises OAuth; "do I"/"can I" floats. The 41st ? framing:
#   "how do i explain X to Y" asks how to COMMUNICATE a thing to a particular audience —
#   distinct from #02 "What is X?" (define it) and #18's how-does-work (mechanism): meet
#   the listener where they are.
#
# Run:  ./examples/target-aur1-52-explainto.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "TARGET (~39 chars):  How do I explain OAuth to a designer?"
say "NLIR (37 src chars):  'how do i explain oauth to a designer'?"
echo -n "  => "; "$NLIR" -e "'how do i explain oauth to a designer'?" --quiet

say "41st ? framing: 'how do i explain X to Y' → COMMUNICATE to an audience (vs #02 define, #18 mechanism)."
