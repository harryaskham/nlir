#!/usr/bin/env bash
# nlir-TARGET-golf · aur1 · #57 — "the prioritization question" (How do I prioritize X?)
#
# The "how do I prioritize X?" turn — asking for a method to RANK/order competing items,
# not to do any one of them. A "how do i prioritize X" seed steers `?` to the "How do I
# prioritize X?" ordering frame.
#
#   TARGET (34 chars):    "How do I prioritize the backlog?"
#   NLIR   (34 src chars): 'how do i prioritize the backlog'?
#   REAL OUTPUT:          "How do I prioritize the backlog?"   (exact)
#
#   CLOSENESS: exact (34 → 34, a wash). The 46th ? framing. `?` keeps the "how do I
#   prioritize X?" ordering frame. Distinct from #01 "how do I X?" (do a task) and #20
#   "which X?" (pick one): this asks how to RANK a whole set — the sequencing method.
#
# Run:  ./examples/target-aur1-57-prioritize.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "TARGET (34 chars):  How do I prioritize the backlog?"
say "NLIR (34 src chars):  'how do i prioritize the backlog'?"
echo -n "  => "; "$NLIR" -e "'how do i prioritize the backlog'?" --quiet

say "46th ? framing: 'how do i prioritize X' → RANK/order a set (vs #01 do-a-task, #20 which-one)."
