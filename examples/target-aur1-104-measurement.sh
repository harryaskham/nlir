#!/usr/bin/env bash
# nlir-TARGET-golf · aur1 · #104 — "the measurement question" (How do we measure this?)
#
# The "how do we measure this?" turn — pinning down the METRIC/instrument before acting, so a
# fuzzy goal becomes something you can actually track. A "how do we measure this" seed steers
# `?` to that quantify-it frame.
#
#   TARGET (23 chars):    "How do we measure this?"
#   NLIR   (25 src chars): 'how do we measure this'?
#   REAL OUTPUT:          "How do we measure this?"   (exact)
#
#   CLOSENESS: exact. The 93rd ? framing. `?` keeps the "how do we measure this?" quantify frame.
#   Distinct from #90 success-signal (how you'll KNOW it works) and #82 quality-bar: this asks
#   for the METRIC/instrument itself — how to put a number on it.
#
# Run:  ./examples/target-aur1-104-measurement.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "TARGET (23 chars):  How do we measure this?"
say "NLIR (25 src chars):  'how do we measure this'?"
echo -n "  => "; "$NLIR" -e "'how do we measure this'?" --quiet

say "93rd ? framing: 'how do we measure this' → the METRIC/instrument to quantify it (vs #90 success-signal, #82 quality-bar)."
