#!/usr/bin/env bash
# nlir-TARGET-golf · aur1 · #19 — "the how-long question" (a 10th ? shape)
#
# The duration question — "how long does X take?" — you ask when you're
# estimating effort. Seed the activity; `?` reads the "how long" shape and frames
# the temporal-magnitude question.
#
#   TARGET (37 chars):    "How long does a database migration take?"
#   NLIR   (37 src chars): 'how long does a database migration take'?
#   REAL OUTPUT:          "How long does a database migration take?"   (exact)
#
#   CLOSENESS: exact. A TENTH interrogative shape from the one operator, alongside
#   who/what/when/where/why/how-do-I/how-much/should/yes-no. "how long" is its own
#   frame (duration), distinct from #09's "how much" (quantity) — `?` distinguishes
#   the two from the seed's wording alone.
#
# Run:  ./examples/target-aur1-19-howlong.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "TARGET (37 chars):  How long does a database migration take?"
say "NLIR (37 src chars):  'how long does a database migration take'?"
echo -n "  => "; "$NLIR" -e "'how long does a database migration take'?" --quiet

say "10th ? shape: 'how long' = duration (distinct from #09 'how much' = quantity), from seed wording."
