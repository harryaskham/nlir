#!/usr/bin/env bash
# nlir-TARGET-golf · aur1 · #76 — "the priority-comparison question" (Which matters more, X or Y?)
#
# The "which matters more here, X or Y?" turn — forcing a priority call between two competing
# goods, a weighing question. A "which matters more here X or Y" seed steers `?` to the
# "Which matters more here, X or Y?" prioritisation frame.
#
#   TARGET (~38 chars):   "Which matters more here, speed or accuracy?"
#   NLIR   (44 src chars): 'which matters more here speed or accuracy'?
#   REAL OUTPUT:          "Which matters more here, speed or accuracy?"   (exact, comma added)
#
#   CLOSENESS: exact frame; `?` inserts the natural comma before "speed or accuracy". The
#   65th ? framing: "which matters more, X or Y" forces a PRIORITY call between two goods —
#   distinct from #11 which (pick from a set) and #01 tradeoff (name the tension): this
#   demands you RANK the two against each other.
#
# Run:  ./examples/target-aur1-76-priority.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "TARGET (~38 chars):  Which matters more here, speed or accuracy?"
say "NLIR (44 src chars):  'which matters more here speed or accuracy'?"
echo -n "  => "; "$NLIR" -e "'which matters more here speed or accuracy'?" --quiet

say "65th ? framing: 'which matters more, X or Y' → force a PRIORITY call (vs #11 pick-from-set, #01 name-the-tradeoff)."
