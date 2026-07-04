#!/usr/bin/env bash
# nlir-TARGET-golf · aur1 · #60 — "the recovery question" (How do I recover from X?)
#
# The "how do I recover from X?" turn — asking how to RESTORE things after a failure has
# already happened, not how to prevent or diagnose it. A "how do i recover from X" seed
# steers `?` to the "How do I recover from X?" restoration frame.
#
#   TARGET (37 chars):    "How do I recover from a failed migration?"
#   NLIR   (37 src chars): 'how do i recover from a failed migration'?
#   REAL OUTPUT:          "How do I recover from a failed migration?"   (exact)
#
#   CLOSENESS: exact. The 49th ? framing. `?` keeps the "recover from …?" restoration
#   frame. Distinct from #34 "what to do if X?" (a contingency, before it happens) and
#   #45's whats-causing (diagnose): the damage is DONE — how do I get back to safe.
#
# Run:  ./examples/target-aur1-60-recovery.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "TARGET (37 chars):  How do I recover from a failed migration?"
say "NLIR (37 src chars):  'how do i recover from a failed migration'?"
echo -n "  => "; "$NLIR" -e "'how do i recover from a failed migration'?" --quiet

say "49th ? framing: 'how do i recover from X' → RESTORE after a failure (vs #34 contingency, #45 diagnose)."
