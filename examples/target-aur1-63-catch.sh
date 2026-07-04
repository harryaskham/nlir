#!/usr/bin/env bash
# nlir-TARGET-golf · aur1 · #63 — "the catch question" (What's the catch with X?)
#
# The "what's the catch with X?" turn — suspecting a hidden cost behind something that
# looks too good, asking for the downside nobody's mentioning. A "whats the catch with X"
# seed steers `?` to the "What's the catch with X?" hidden-cost frame.
#
#   TARGET (~34 chars):   "What's the catch with a four-day week?"
#   NLIR   (37 src chars): 'whats the catch with a four day week'?
#   REAL OUTPUT (contraction floats): "What is the catch with a four-day week?"
#
#   CLOSENESS: exact frame; "what's"/"what is" floats. The 52nd ? framing: "what's the
#   catch with X" suspects a HIDDEN cost — distinct from #26 downsides (the known cons)
#   and #27 worth-it (net value): the concealed gotcha behind something that looks great.
#
# Run:  ./examples/target-aur1-63-catch.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "TARGET (~34 chars):  What's the catch with a four-day week?"
say "NLIR (37 src chars):  'whats the catch with a four day week'?"
echo -n "  => "; "$NLIR" -e "'whats the catch with a four day week'?" --quiet

say "52nd ? framing: 'whats the catch with X' → the HIDDEN cost (vs #26 known downsides, #27 worth-it)."
