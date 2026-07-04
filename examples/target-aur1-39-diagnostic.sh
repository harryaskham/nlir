#!/usr/bin/env bash
# nlir-TARGET-golf · aur1 · #39 — "the diagnostic question" (How do I tell if…?)
#
# The "how can I tell if X?" turn — asking for a TEST/signal to detect a property,
# not how to build or fix it. A "how to tell if X" seed steers `?` to the "How can
# I tell if …?" diagnostic frame.
#
#   TARGET (~40 chars):   "How can I tell if my code is thread-safe?"
#   NLIR   (37 src chars): 'how to tell if my code is thread safe'?
#   REAL OUTPUT:          "How can I tell if my code is thread safe?"   (exact)
#
#   CLOSENESS: exact. The 28th ? framing. `?` reads "how to tell if …" as a
#   detection question and builds "How can I tell if …?". Distinct from #01 "How do
#   I …?" (do a task) and #34 "What's wrong with X?" (find flaws): this asks for a
#   TEST to check a property — the how-would-I-know turn.
#
# Run:  ./examples/target-aur1-39-diagnostic.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "TARGET (~40 chars):  How can I tell if my code is thread-safe?"
say "NLIR (37 src chars):  'how to tell if my code is thread safe'?"
echo -n "  => "; "$NLIR" -e "'how to tell if my code is thread safe'?" --quiet

say "28th ? framing: 'how to tell if X' → a DETECTION/test question (vs #01 do-a-task, #34 find-flaws)."
