#!/usr/bin/env bash
# nlir-TARGET-golf · aur1 · #29 — "the consequences question" (What happens if…?)
#
# The "what are the consequences of X?" turn — asking for downstream effects
# before acting. A "consequences of X-ing" seed steers `?` to the "What are the
# consequences of …?" impact frame.
#
#   TARGET (54 chars):    "What are the consequences of dropping the production index?"
#   NLIR   (48 src chars): 'consequences of dropping the production index'?
#   REAL OUTPUT:          "What are the consequences of dropping the production index?"  (exact)
#
#   CLOSENESS: exact. The 18th ? framing. `?` reads "consequences of …" as an
#   impact/effects question and builds "What are the consequences of …?" — the
#   look-before-you-leap turn. Distinct from #08 "Should I …?" (the decision) and
#   #06 "Why …?" (the reason): this asks what FOLLOWS from an action.
#
# Run:  ./examples/target-aur1-29-consequences.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "TARGET (54 chars):  What are the consequences of dropping the production index?"
say "NLIR (48 src chars):  'consequences of dropping the production index'?"
echo -n "  => "; "$NLIR" -e "'consequences of dropping the production index'?" --quiet

say "18th ? framing: 'consequences of X' → 'What are the consequences of …?' (impact, not decision)."
