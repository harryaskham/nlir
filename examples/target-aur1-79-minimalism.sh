#!/usr/bin/env bash
# nlir-TARGET-golf · aur1 · #79 — "the minimalism question" (What's the simplest thing that could work?)
#
# The "what's the simplest thing that could work?" turn — the YAGNI check, asking for the
# least-effort solution that still solves the problem. A "whats the simplest thing that could
# work" seed steers `?` to that minimalism frame.
#
#   TARGET (~38 chars):   "What's the simplest thing that could work?"
#   NLIR   (41 src chars): 'whats the simplest thing that could work'?
#   REAL OUTPUT (contraction floats): "What is the simplest thing that could work?"
#
#   CLOSENESS: exact frame; "what's"/"what is" floats. The 68th ? framing: "the simplest
#   thing that could work" asks for the MINIMAL viable solution — distinct from #69 first-step
#   (the next action) and #21 best-way (the ideal method): the least you can get away with.
#
# Run:  ./examples/target-aur1-79-minimalism.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "TARGET (~38 chars):  What's the simplest thing that could work?"
say "NLIR (41 src chars):  'whats the simplest thing that could work'?"
echo -n "  => "; "$NLIR" -e "'whats the simplest thing that could work'?" --quiet

say "68th ? framing: 'simplest thing that could work' → the MINIMAL viable solution (vs #69 first-step, #21 best-way)."
