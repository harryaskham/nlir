#!/usr/bin/env bash
# nlir-golf · aur1 · #60 — "the perspective wheel" (one claim, every axis of the basis) · MILESTONE
#
# Sixtieth example — a capstone. Back at #40 I refracted a claim through five lenses;
# here is the full WHEEL, and it's organised around msm0's semantic basis (#30): each
# operator moves the claim along ONE axis of meaning, so pointing them all at a single
# statement shows you that statement from every independent direction at once.
#
#   THE PERSPECTIVE WHEEL  on "we should sunset the legacy API"
#     TOPIC     #x  → "Legacy API sunset"                       (what it's ABOUT)
#     LENGTH ↓  ~x  → "Sunset the legacy API."                  (the gist)
#     LENGTH ↑  >x  → "We should retire the legacy API…because keeping it alongside
#                      newer versions adds maintenance overhead, security surface…"  (the case)
#     POLARITY  !x  → "we should not sunset the legacy API"     (the flip)
#     REGISTER  @x  → "We recommend deprecating the legacy API." (dressed up)
#     MODE      x?  → "Should we sunset the legacy API?"        (interrogated)
#
# Six sigils, six independent directions — topic, information (down AND up), polarity,
# register, and mode. Every one is a coordinate on the basis; none is reachable from
# another (that's what "orthogonal axes" means). It's the whole cognitive toolkit as a
# single instrument panel, sixty examples of exploration compressed into one line: give
# me a claim and I'll show you it filed, summarised, argued, negated, formalised, and
# questioned — all at once.
#
# Run:  ./examples/golf-aur1-60-wheel.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
C='we should sunset the legacy API'

say "THE PERSPECTIVE WHEEL  #x ~x >x !x @x x?  — one claim refracted along every axis of the basis"
echo   "  claim: $C"
echo -n "  #x  TOPIC     => "; "$NLIR" -e "#'$C'" --quiet
echo -n "  ~x  LENGTH↓   => "; "$NLIR" -e "~'$C'" --quiet
echo -n "  >x  LENGTH↑   => "; "$NLIR" -e ">'$C'" --quiet | fold -s -w 82 | sed '2,$s/^/                 /'
echo -n "  !x  POLARITY  => "; "$NLIR" -e "!'$C'" --quiet
echo -n "  @x  REGISTER  => "; "$NLIR" -e "@'$C'" --quiet
echo -n "  x?  MODE      => "; "$NLIR" -e "'$C'?" --quiet

say "Six operators, six orthogonal directions — the semantic basis (#30/#40) as one instrument. The whole toolkit, one line."
