#!/usr/bin/env bash
# nlir-TARGET-golf · aur1 · #98 — "the catch question" (What's the catch?)
#
# The "what's the catch?" turn — the instinctive probe for the HIDDEN downside of something that
# sounds too good, the unstated cost behind the upside. A "whats the catch" seed steers `?` to
# that hidden-cost frame.
#
#   TARGET (16 chars):    "What's the catch?"
#   NLIR   (18 src chars): 'whats the catch'?
#   REAL OUTPUT (contraction floats): "What's the catch?"   (exact)
#
#   CLOSENESS: exact. The 87th ? framing. `?` keeps the "what's the catch?" hidden-cost frame.
#   Distinct from #96 failure-mode (what breaks) and #27 worth-it (net value): this asks for the
#   concealed downside of an offer that looks all-upside.
#
# Run:  ./examples/target-aur1-98-catch.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "TARGET (16 chars):  What's the catch?"
say "NLIR (18 src chars):  'whats the catch'?"
echo -n "  => "; "$NLIR" -e "'whats the catch'?" --quiet

say "87th ? framing: 'whats the catch' → the HIDDEN downside/unstated cost (vs #96 failure-mode, #27 worth-it)."
