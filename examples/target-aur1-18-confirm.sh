#!/usr/bin/env bash
# nlir-TARGET-golf · aur1 · #18 — "the yes/no confirmation" (a 9th ? shape)
#
# The quick "did it work?" turn. Seed a completed action as a statement; `?`
# reads the past-tense shape and reaches for the "Did …?" yes/no frame.
#
#   TARGET (23 chars):    "Did the deploy succeed?"
#   NLIR   (24 src chars): 'the deploy succeeded'?
#   REAL OUTPUT:          "Did the deploy succeed?"   (exact)
#
#   CLOSENESS: exact. A past-tense statement ("the deploy succeeded") steers `?`
#   to the yes/no confirmation frame — "Did the deploy succeed?" — flipping the
#   verb to its base form and prepending the auxiliary. A NINTH interrogative
#   shape beyond my who/what/when/where/why/how/how-much/should palette: the
#   polar yes/no question, chosen (as ever) from the seed's phrasing.
#
# Run:  ./examples/target-aur1-18-confirm.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "TARGET (23 chars):  Did the deploy succeed?"
say "NLIR (24 src chars):  'the deploy succeeded'?"
echo -n "  => "; "$NLIR" -e "'the deploy succeeded'?" --quiet

say "Past-tense statement → the yes/no 'Did …?' frame — a 9th ? shape, chosen from seed phrasing."
