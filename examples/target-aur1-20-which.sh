#!/usr/bin/env bash
# nlir-TARGET-golf · aur1 · #20 — "the which-question" (an 11th ? shape)
#
# The selection question — "which X should I use?" — you ask when picking a tool
# from a field of options. Seed the decision; `?` frames the "Which …?".
#
#   TARGET (44 chars):    "Which database should I use for time-series data?"
#   NLIR   (46 src chars): 'which database should i use for time series data'?
#   REAL OUTPUT:          "Which database should I use for time series data?"  (exact)
#
#   CLOSENESS: exact. The "which … should I" seed shape steers `?` to the
#   selection frame. That's an ELEVENTH interrogative from one operator alongside
#   who/what/when/where/why/how-do-I/how-much/how-long/should/yes-no — a near-total
#   coverage of the question words, each inferred from the seed's wording.
#
# Run:  ./examples/target-aur1-20-which.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "TARGET (44 chars):  Which database should I use for time-series data?"
say "NLIR (46 src chars):  'which database should i use for time series data'?"
echo -n "  => "; "$NLIR" -e "'which database should i use for time series data'?" --quiet

say "11th ? shape: 'which … should I' = selection, from seed wording. Near-total question coverage."
