#!/usr/bin/env bash
# nlir-TARGET-golf · aur1 · #99 — "the definition-of-done question" (What does "done" mean here?)
#
# The "what does done mean here?" turn — pinning down the completion criteria BEFORE starting,
# so "done" isn't a moving target. A "what does done mean here" seed steers `?` to that
# define-completion frame.
#
#   TARGET (24 chars):    "What does done mean here?"
#   NLIR   (28 src chars): 'what does done mean here'?
#   REAL OUTPUT (adds quotes): What does "done" mean here?
#
#   CLOSENESS: exact frame (`?` even quotes "done" for emphasis). The 88th ? framing. Distinct
#   from #93 quality-bar (what does GOOD look like — the standard) and #90 success-signal (how
#   you'll KNOW it works): this pins the COMPLETION line — when to stop.
#
# Run:  ./examples/target-aur1-99-doneness.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "TARGET (24 chars):  What does done mean here?"
say "NLIR (28 src chars):  'what does done mean here'?"
echo -n "  => "; "$NLIR" -e "'what does done mean here'?" --quiet

say "88th ? framing: 'what does done mean here' → pin the COMPLETION criteria / when to stop (vs #93 quality-bar, #90 success-signal)."
