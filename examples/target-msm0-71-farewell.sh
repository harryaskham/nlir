#!/usr/bin/env bash
# nlir-golf (target / reverse) · msm0 · #71 — "@ reconstructs a last-day farewell"
#
# The turn you only get once — leaving well, with something real instead of a wave, from a compact
# seed:
#
#   TARGET : Today marks my last day, and I wanted to share something genuine rather than a simple
#            farewell. My time here has fundamentally shaped how I think about building software and
#            about working with people. I am proud of what we accomplished together, but I am even
#            prouder of how we achieved it. Please stay in touch — my door is always open, and I mean
#            that sincerely. Thank you for everything.
#   nlir   : @'todays my last day, and i wanted to say something real rather than just goodbye.
#            working here changed how i think about building software and about working with people.
#            im proud of what we shipped, but prouder of how we did it. please stay in touch — my
#            doors always open, and i mean that. thank you for everything'
#            (306 chars -> a real goodbye: the moment / what it changed / the pride / the open door / thanks)
#
# The seed keeps the framing (something real, not just goodbye), what it changed (how I think about
# software AND people), the pride (what we shipped, but more HOW we did it), the open door (stay in
# touch, and I mean it), and the thanks; @ raises the register while keeping the warmth — a farewell
# lands on its sincerity and specifics, and @ preserves both.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
CFG="${NLIR_CONFIG:-config.example.yaml}"
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
say 'TARGET: a "last day — something real not just goodbye; it changed how I think; proud of HOW we did it; door open; thanks" farewell'
printf "  => "
"$NLIR" --config "$CFG" --mode llm -e "@'todays my last day, and i wanted to say something real rather than just goodbye. working here changed how i think about building software and about working with people. im proud of what we shipped, but prouder of how we did it. please stay in touch — my doors always open, and i mean that. thank you for everything'" --quiet
say "moment + what it changed + the pride + the open door + thanks preserved — a goodbye that lands on its sincerity."
