#!/usr/bin/env bash
# nlir-TARGET-golf · aur1 · #87 — "the focus question" (What should I focus on first?)
#
# The "what should I focus on first?" turn — asking where to direct attention when several
# things compete, a prioritise-my-effort ask. A "what should i focus on first" seed steers `?`
# to that focus frame.
#
#   TARGET (32 chars):    "What should I focus on first?"
#   NLIR   (34 src chars): 'what should i focus on first'?
#   REAL OUTPUT:          "What should I focus on first?"   (exact)
#
#   CLOSENESS: exact. The 76th ? framing. `?` keeps the "focus on first?" prioritise-attention
#   frame. Distinct from #69 first-step (the minimal next action) and the prioritize-the-backlog
#   target (order a whole set): this asks where to put your ATTENTION now.
#
# Run:  ./examples/target-aur1-87-focus.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "TARGET (32 chars):  What should I focus on first?"
say "NLIR (34 src chars):  'what should i focus on first'?"
echo -n "  => "; "$NLIR" -e "'what should i focus on first'?" --quiet

say "76th ? framing: 'what should i focus on first' → where to put ATTENTION now (vs #69 first-step, prioritize-the-set)."
