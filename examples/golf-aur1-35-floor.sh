#!/usr/bin/env bash
# nlir-golf · aur1 · #35 — "the compression floor" (repeated < SATURATES; an honest surprise)
#
# I expected a ladder: <x, <<x, <<<x marching down to a punchy six-word line. WRONG,
# and the wrongness is the lesson. Repeated shorten hits an INFORMATION FLOOR — each
# `<` trims a little less (diminishing returns), asymptoting to the shortest form
# that still carries the WHOLE meaning. `<` won't crush a paragraph to a haiku,
# because it never drops information — it only tightens phrasing.
#
#   INFORMATION FLOOR   x > <x > <<x > <<<x → (asymptote, not → micro-line)
#     x    (41 words)  the full checkout-conversion story
#     <x   (~34 words) tightened
#     <<x  (~32 words) …a little more
#     <<<x (~27 words) …diminishing returns, near the floor (still the FULL story)
#
# The length axis is bounded BELOW by content: to go shorter than the concise-full
# form you must drop INFORMATION with ~ (which distils monotonically, #05), not
# apply < again. Contrast the taxonomy: ~ intensifies past the floor by shedding
# detail; @ saturates in register (#23); ! inverts (#25); < bottoms out at meaning.
#
# Run:  ./examples/golf-aur1-35-floor.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
wc_w() { printf '%s' "$1" | wc -w | tr -d ' '; }
S='our checkout page was losing thirty percent of users at the payment step because the form reset every time a card was declined, so we made it preserve the entered details and show an inline error, and conversion recovered almost completely'

say "COMPRESSION FLOOR  < / << / <<<  — repeated shorten SATURATES to a concise floor (not a ladder)"
echo   "  x    ($(wc_w "$S")w): the full story"
A="$("$NLIR" -e "<'$S'"   --quiet)"; echo "  <x   ($(wc_w "$A")w): $A" | fold -s -w 88 | sed '2,$s/^/       /'
B="$("$NLIR" -e "<<'$S'"  --quiet)"; echo "  <<x  ($(wc_w "$B")w): $B" | fold -s -w 88 | sed '2,$s/^/       /'
C="$("$NLIR" -e "<<<'$S'" --quiet)"; echo "  <<<x ($(wc_w "$C")w): $C" | fold -s -w 88 | sed '2,$s/^/       /'

say "< asymptotes to the concise-FULL-meaning floor (diminishing returns). To go shorter, drop info with ~ (#05)."
