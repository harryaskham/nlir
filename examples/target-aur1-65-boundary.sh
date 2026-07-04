#!/usr/bin/env bash
# nlir-TARGET-golf · aur1 · #65 — "the boundary question" (How do I say no to X politely?)
#
# The "how do I say no to X politely?" turn — asking to DECLINE something gracefully, a
# social/boundary ask. A "how do i say no to X politely" seed steers `?` to the "How do I
# say no to X politely?" refusal frame.
#
#   TARGET (38 chars):    "How do I say no to extra work politely?"
#   NLIR   (39 src chars): 'how do i say no to extra work politely'?
#   REAL OUTPUT:          "How do I say no to extra work politely?"   (exact)
#
#   CLOSENESS: exact. The 54th ? framing. `?` keeps the "say no to … politely?" refusal
#   frame. Distinct from #59 handling (navigate a situation) and #51 cessation (how to
#   stop doing something): this is declining a request gracefully — a boundary.
#
# Run:  ./examples/target-aur1-65-boundary.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "TARGET (38 chars):  How do I say no to extra work politely?"
say "NLIR (39 src chars):  'how do i say no to extra work politely'?"
echo -n "  => "; "$NLIR" -e "'how do i say no to extra work politely'?" --quiet

say "54th ? framing: 'how do i say no to X politely' → decline gracefully / a BOUNDARY (vs #59 handling, #51 cessation)."
