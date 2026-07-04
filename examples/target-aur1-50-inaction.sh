#!/usr/bin/env bash
# nlir-TARGET-golf · aur1 · #50 — "the inaction question" (What if I don't X?)
#
# The "what if I don't X?" turn — asking the cost of NOT acting, the downside of the
# status quo. A "what if i dont X" seed steers `?` to the "What if I don't X?" inaction
# frame.
#
#   TARGET (26 chars):    "What if I don't add tests?"
#   NLIR   (26 src chars): 'what if i dont add tests'?
#   REAL OUTPUT:          "What if I don't add tests?"   (exact)
#
#   CLOSENESS: exact (26 → 26, a wash). The 39th ? framing. `?` restores the
#   apostrophe in "don't" and keeps the conditional. Distinct from #29 "consequences
#   of X?" (effects of an ACTION): this asks the cost of INACTION — the what-happens-if-
#   I-skip-it turn, the mirror of doing it.
#
# Run:  ./examples/target-aur1-50-inaction.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "TARGET (26 chars):  What if I don't add tests?"
say "NLIR (26 src chars):  'what if i dont add tests'?"
echo -n "  => "; "$NLIR" -e "'what if i dont add tests'?" --quiet

say "39th ? framing: 'what if i dont X' → the cost of INACTION (vs #29 consequences of an action)."
