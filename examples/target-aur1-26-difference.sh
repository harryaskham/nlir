#!/usr/bin/env bash
# nlir-TARGET-golf · aur1 · #26 — "the difference question" (compare two things)
#
# The "what's the difference between X and Y?" turn — asking for a contrast, not a
# definition of either alone. A "difference between X and Y" seed steers `?` to the
# comparison frame.
#
#   TARGET (41 chars):    "What is the difference between TCP and UDP?"
#   NLIR   (32 src chars): 'difference between tcp and udp'?
#   REAL OUTPUT:          "What is the difference between TCP and UDP?"   (exact)
#
#   CLOSENESS: exact. The 15th ? framing. `?` recognises the "difference between …
#   and …" pattern as a contrast question and uppercases the acronyms. Distinct
#   from #02's "What is X?" definition and #20's "Which X?" selection — here it's a
#   two-subject comparison, the "compare these for me" turn.
#
# Run:  ./examples/target-aur1-26-difference.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "TARGET (41 chars):  What is the difference between TCP and UDP?"
say "NLIR (32 src chars):  'difference between tcp and udp'?"
echo -n "  => "; "$NLIR" -e "'difference between tcp and udp'?" --quiet

say "15th ? framing: 'difference between X and Y' → a contrast question (vs #02 'What is X?' def)."
