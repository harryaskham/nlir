#!/usr/bin/env bash
# nlir-TARGET-golf · aur1 · #72 — "the blast-radius question" (What breaks if I change this?)
#
# The "what breaks if I change this?" turn — asking for the downstream fallout of a change,
# an impact/blast-radius check before you touch something. A "what breaks if i change this"
# seed steers `?` to the "What breaks if I change this?" fallout frame.
#
#   TARGET (28 chars):    "What breaks if I change this?"
#   NLIR   (30 src chars): 'what breaks if i change this'?
#   REAL OUTPUT:          "What breaks if I change this?"   (exact)
#
#   CLOSENESS: exact. The 61st ? framing. `?` keeps the "what breaks if …?" blast-radius
#   frame. Distinct from #29 consequences (general fallout of an action) and #10 what-if
#   (a hypothetical outcome): this asks specifically what DOWNSTREAM depends on the thing
#   you're about to touch.
#
# Run:  ./examples/target-aur1-72-blastradius.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "TARGET (28 chars):  What breaks if I change this?"
say "NLIR (30 src chars):  'what breaks if i change this'?"
echo -n "  => "; "$NLIR" -e "'what breaks if i change this'?" --quiet

say "61st ? framing: 'what breaks if i change this' → the BLAST RADIUS (vs #29 consequences, #10 what-if)."
