#!/usr/bin/env bash
# nlir-TARGET-golf · aur1 · #78 — "the retrospective question" (What would you do differently?)
#
# The "what would you do differently?" turn — a retrospective, asking what you'd change with
# hindsight after something is done, not what to do next. A "what would you do differently"
# seed steers `?` to that reflective frame.
#
#   TARGET (32 chars):    "What would you do differently?"
#   NLIR   (34 src chars): 'what would you do differently'?
#   REAL OUTPUT:          "What would you do differently?"   (exact)
#
#   CLOSENESS: exact. The 67th ? framing. `?` keeps the "do differently?" retrospective
#   frame. Distinct from #35 what-to-do-if (a future contingency) and #01 how-do-I (do it
#   now): this looks BACK — with hindsight, what would you change?
#
# Run:  ./examples/target-aur1-78-retrospective.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "TARGET (32 chars):  What would you do differently?"
say "NLIR (34 src chars):  'what would you do differently'?"
echo -n "  => "; "$NLIR" -e "'what would you do differently'?" --quiet

say "67th ? framing: 'what would you do differently' → a RETROSPECTIVE with hindsight (vs #35 what-to-do-if, #01 how-do-I)."
