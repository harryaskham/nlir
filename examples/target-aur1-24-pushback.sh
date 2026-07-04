#!/usr/bin/env bash
# nlir-TARGET-golf · aur1 · #24 — "the diplomatic pushback" (@ ∘ !)
#
# The disagree-tactfully turn: reject a proposal without sounding blunt. `!`
# flips the proposal into "don't do X", and `@` dresses that refusal in
# professional, non-confrontational language.
#
#   TARGET (44 chars):    "Code review must not be omitted prior to merging."
#   NLIR   (33 src chars): @!'skip code review before merging'
#   REAL OUTPUT (verb floats skipped/omitted): "Code review must not be skipped/omitted prior to merging."
#
#   HOW IT NESTS: !'skip code review before merging' → "don't skip code review
#   before merging"; @ then lifts that into a formal recommendation — "must not
#   be omitted prior to merging". You seed only the thing to reject; the tact and
#   the register are generated. (Same @!x machine as concept #06's devil's
#   advocate, here used to reconstruct a real review-comment turn.)
#
# Run:  ./examples/target-aur1-24-pushback.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "TARGET (44 chars):  Code review must not be omitted prior to merging."
say "NLIR (33 src chars):  @!'skip code review before merging'   —  @ ∘ !"
echo -n "  => "; "$NLIR" -e "@!'skip code review before merging'" --quiet

say "! rejects the proposal, @ makes the refusal diplomatic — seed the thing to reject, get tact free."
