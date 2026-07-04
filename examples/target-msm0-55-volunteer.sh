#!/usr/bin/env bash
# nlir-golf (target / reverse) · msm0 · #55 — "@ reconstructs volunteering for a stretch"
#
# The "put my hand up for something hard" turn — offering to own a big lift, with the
# credibility to back it, from a compact seed:
#
#   TARGET : I would like to volunteer to lead the observability overhaul. I recognize
#            this is a substantial undertaking and falls outside my usual scope of
#            responsibility; however, having handled the majority of our recent production
#            incident investigations, I believe I have a strong understanding of the
#            existing gaps. I am prepared to take ownership of this initiative with your
#            support.
#   nlir   : @'id like to put my hand up to lead the observability overhaul. i know its a
#            big lift and outside my usual area, but ive been the one debugging most of our
#            prod incidents lately and i think i understand the gaps better than anyone. im
#            ready to own it if youll back me'
#            (264 chars -> a credible offer: the ask / the honesty / the evidence / the terms)
#
# The seed keeps the offer (lead the overhaul), the honesty (big lift, outside my area),
# the evidence (I've been debugging the incidents, I know the gaps), and the terms (ready
# to own it if you back me); @ raises the register while keeping the earned confidence —
# volunteering works when it's backed by a track record, and @ keeps the record front and
# centre.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
CFG="${NLIR_CONFIG:-config.example.yaml}"
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
say 'TARGET: an "I want to lead the observability overhaul — I have been debugging the incidents, back me" offer'
printf "  => "
"$NLIR" --config "$CFG" --mode llm -e "@'id like to put my hand up to lead the observability overhaul. i know its a big lift and outside my usual area, but ive been the one debugging most of our prod incidents lately and i think i understand the gaps better than anyone. im ready to own it if youll back me'" --quiet
say "offer + honesty + evidence + terms preserved — volunteering that's backed by a track record."
