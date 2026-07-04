#!/usr/bin/env bash
# nlir-TARGET-golf · aur1 · #27 — "the worth-it question" (value judgement)
#
# The "is X worth it?" turn — asking whether something is worth the investment of
# time/money/effort. An "X worth Y-ing" seed steers `?` to the "Is X worth …?"
# value-judgement frame.
#
#   TARGET (33 chars):    "Is React worth learning in 2026?"
#   NLIR   (30 src chars): 'react worth learning in 2026'?
#   REAL OUTPUT:          "Is React worth learning in 2026?"   (exact)
#
#   CLOSENESS: exact. The 16th ? framing. `?` recognises "worth learning" as a
#   value/ROI judgement and builds "Is … worth …?", capitalising the proper noun
#   and keeping the year. Distinct from #08's "Should I …?" (decision) — "worth it"
#   asks about VALUE, not the action itself.
#
# Run:  ./examples/target-aur1-27-worthit.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "TARGET (33 chars):  Is React worth learning in 2026?"
say "NLIR (30 src chars):  'react worth learning in 2026'?"
echo -n "  => "; "$NLIR" -e "'react worth learning in 2026'?" --quiet

say "16th ? framing: 'X worth Y-ing' → 'Is X worth …?' value judgement (vs #08 'Should I…?' decision)."
