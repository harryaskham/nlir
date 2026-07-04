#!/usr/bin/env bash
# nlir-TARGET-golf · aur1 · #115 — "the cui-bono question" (Who benefits from this?)
#
# The "who benefits from this?" turn — follow-the-incentives: cui bono? Naming who GAINS from a
# proposal or situation surfaces the hidden motives and stakeholders behind it. A "who benefits
# from this" seed steers `?` to that incentive frame.
#
#   TARGET (23 chars):    "Who benefits from this?"
#   NLIR   (25 src chars): 'who benefits from this'?
#   REAL OUTPUT:          "Who benefits from this?"   (exact)
#
#   CLOSENESS: exact. The 104th ? framing. `?` keeps the "who benefits?" cui-bono frame. Distinct
#   from #94 stakeholder (who to notify) and #54 ownership: this asks who GAINS — follow the
#   incentives to the motive.
#
# Run:  ./examples/target-aur1-115-cuibono.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "TARGET (23 chars):  Who benefits from this?"
say "NLIR (25 src chars):  'who benefits from this'?"
echo -n "  => "; "$NLIR" -e "'who benefits from this'?" --quiet

say "104th ? framing: 'who benefits from this' → cui bono / follow-the-incentives to the motive (vs #94 stakeholder, #54 ownership)."
