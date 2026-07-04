#!/usr/bin/env bash
# nlir-TARGET-golf · aur1 · #47 — "the trigger question" (How do I know when to X?)
#
# The "how do I know when to X?" turn — asking for the SIGNAL/threshold that should
# prompt an action, not how to do it. A "how do i know when to X" seed steers `?` to
# the "How do I know when to X?" trigger frame.
#
#   TARGET (30 chars):    "How do I know when to scale up?"
#   NLIR   (30 src chars): 'how do i know when to scale up'?
#   REAL OUTPUT:          "How do I know when to scale up?"   (exact)
#
#   CLOSENESS: exact (30 → 30, a wash). The 36th ? framing. `?` keeps the "how do I
#   know when to …?" trigger frame. Distinct from #11 "When …?" (a time) and #39 "How
#   can I tell if …?" (detect a current property): this asks for the SIGNAL that means
#   it's time to act — the what-should-tip-me-off turn.
#
# Run:  ./examples/target-aur1-47-trigger.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "TARGET (30 chars):  How do I know when to scale up?"
say "NLIR (30 src chars):  'how do i know when to scale up'?"
echo -n "  => "; "$NLIR" -e "'how do i know when to scale up'?" --quiet

say "36th ? framing: 'how do i know when to X' → the SIGNAL to act (vs #11 a time, #39 detect a property)."
