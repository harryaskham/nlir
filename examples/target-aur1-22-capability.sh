#!/usr/bin/env bash
# nlir-TARGET-golf · aur1 · #22 — "the capability question" (do-you)
#
# The "do you support X?" turn — asking a tool/service whether it can do
# something. Seed the capability; `?` frames the polar "Do you …?" question.
#
#   TARGET (23 chars):    "Do you support webhooks?"
#   NLIR   (21 src chars): 'you support webhooks'?
#   REAL OUTPUT:          "Do you support webhooks?"   (exact)
#
#   CLOSENESS: exact. A second-person present-tense capability seed ("you support
#   webhooks") steers `?` to the "Do you …?" auxiliary frame — distinct from #18's
#   past-tense yes/no ("the deploy succeeded" → "Did …?"). A thirteenth ? framing:
#   the operator picks "Do" vs "Did" from the seed's tense.
#
# Run:  ./examples/target-aur1-22-capability.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "TARGET (23 chars):  Do you support webhooks?"
say "NLIR (21 src chars):  'you support webhooks'?"
echo -n "  => "; "$NLIR" -e "'you support webhooks'?" --quiet

say "13th ? framing: present-tense 'you support…' → 'Do you…?' (vs #18 past-tense 'Did…?')."
