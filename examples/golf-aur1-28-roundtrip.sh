#!/usr/bin/env bash
# nlir-golf · aur1 · #28 — "the non-invertible pair" (length ops are relative)
#
# I expected a round-trip: expand then shorten should return to the seed, right?
# <>x ≈ x? WRONG — and the failure is the interesting part. Expanding a 10-word
# sentence and then shortening the result lands at a MEDIUM length, NOT back at
# the original. `<` and `>` are RELATIVE nudges: each adjusts length relative to
# ITS OWN input, so there's no absolute anchor to return to.
#
#   NOT A ROUND-TRIP   <>x  ≠  x
#     x    (10 words)  "back up your database before running the migration"
#     >x   (~130 words) a full paragraph on why + how + recovery
#     <>x  (~75 words)  shorter than >x, but still ~7x the seed — NOT back to x
#
# This completes a little taxonomy of operator dynamics:
#     !     INVERTIBLE       — !!x = x, exact round-trip (#25)
#     @     ABSOLUTE fixpoint— @@x ≈ @x, snaps to a fixed register (#23)
#     < / > RELATIVE         — no fixpoint, no inverse; each nudge is relative (this one)
# An honest NEGATIVE result: knowing an operator pair does NOT invert is as useful
# as knowing one does — don't reach for <> expecting your original text back.
#
# Run:  ./examples/golf-aur1-28-roundtrip.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
wc_words() { printf '%s' "$1" | wc -w | tr -d ' '; }
S='back up your database before running the migration'

say "NON-INVERTIBLE  x / >x / <>x  — does expand-then-shorten round-trip back to x? (no)"
echo "  x   ($(wc_words "$S") words): $S"
EX="$("$NLIR" -e ">'$S'" --quiet)";   echo "  >x  ($(wc_words "$EX") words): expanded to a full paragraph"
RT="$("$NLIR" -e "<>'$S'" --quiet)";  echo "  <>x ($(wc_words "$RT") words): $RT" | fold -s -w 88 | sed '2,$s/^/       /'

say "<>x lands MID-LENGTH, not at x. < and > are RELATIVE nudges (no fixpoint) — cf ! invertible, @ absolute."
