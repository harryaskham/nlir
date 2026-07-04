#!/usr/bin/env bash
# nlir-TARGET-golf · aur1 · #83 — "the re-evaluation question" (Does this still make sense?)
#
# The "does this still make sense?" turn — re-checking a past decision against the present,
# asking whether something that was once right still holds. A "does this still make sense"
# seed steers `?` to the "Does this still make sense?" re-evaluation frame.
#
#   TARGET (26 chars):    "Does this still make sense?"
#   NLIR   (28 src chars): 'does this still make sense'?
#   REAL OUTPUT:          "Does this still make sense?"   (exact)
#
#   CLOSENESS: exact. The 72nd ? framing. `?` keeps the "still make sense?" re-evaluation
#   frame. Distinct from #53 good-idea (is a plan sound now) and #61 lateness (has a window
#   closed): the word "still" makes it a RE-CHECK of something previously decided.
#
# Run:  ./examples/target-aur1-83-reeval.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "TARGET (26 chars):  Does this still make sense?"
say "NLIR (28 src chars):  'does this still make sense'?"
echo -n "  => "; "$NLIR" -e "'does this still make sense'?" --quiet

say "72nd ? framing: 'does this still make sense' → RE-CHECK a past decision (the 'still' vs #53 good-idea, #61 lateness)."
