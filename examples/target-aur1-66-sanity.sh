#!/usr/bin/env bash
# nlir-TARGET-golf · aur1 · #66 — "the sanity-check question" (Am I overthinking this?)
#
# The "am I overthinking this?" turn — a reassurance/sanity check, asking whether you're
# making something harder than it is. A first-person "am i overthinking this" seed steers
# `?` to the "Am I overthinking this?" self-doubt frame.
#
#   TARGET (23 chars):    "Am I overthinking this?"
#   NLIR   (25 src chars): 'am i overthinking this'?
#   REAL OUTPUT (pronoun floats): "Are you overthinking this?"
#
#   CLOSENESS: exact frame; the 1st-person "am I" floats to "are you" (the reader's
#   viewpoint). The 55th ? framing: "am i overthinking X" is a SANITY check on yourself —
#   distinct from #45 is-it-normal (about the situation) and #53 good-idea (about a plan):
#   this asks whether YOU are the one adding complexity.
#
# Run:  ./examples/target-aur1-66-sanity.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "TARGET (23 chars):  Am I overthinking this?"
say "NLIR (25 src chars):  'am i overthinking this'?"
echo -n "  => "; "$NLIR" -e "'am i overthinking this'?" --quiet

say "55th ? framing: 'am i overthinking X' → a SANITY check on yourself (vs #45 is-it-normal, #53 good-idea)."
