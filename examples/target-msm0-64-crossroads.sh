#!/usr/bin/env bash
# nlir-golf (target / reverse) · msm0 · #64 — "@ reconstructs a career-crossroads ask"
#
# A vulnerable, real turn — asking a mentor for honest guidance at a genuine fork, from a
# compact seed:
#
#   TARGET : I would appreciate your candid perspective on a matter I have been considering.
#            Having worked as an individual contributor for six years, I find myself genuinely
#            uncertain about whether to transition into management. On one hand, I value the
#            deep technical work and am concerned I would miss it; on the other, I have recently
#            found myself more energized by removing obstacles for the team than by writing code
#            myself. How did you know it was the right time to make that transition?
#   nlir   : @'can i get your honest take on something? ive been an IC for six years and im
#            genuinely torn about whether to move into management. part of me loves the deep
#            technical work and worries id miss it, but part of me is more energized lately by
#            unblocking the team than by writing code myself. how did you know when it was time?'
#            (321 chars -> a crossroads ask: the request / the tension / both pulls / the question)
#
# The seed keeps the ask (your honest take), the fork (IC six years, torn about management), both
# pulls (miss the deep work vs energized by unblocking the team), and the real question (how did
# you know when); @ raises the register while keeping the candor — a mentorship ask lands because
# it's honest about both sides of the pull, and @ preserves that balance.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
CFG="${NLIR_CONFIG:-config.example.yaml}"
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
say 'TARGET: an "IC six years, torn about management — miss the code vs energized unblocking the team — how did you know?" ask'
printf "  => "
"$NLIR" --config "$CFG" --mode llm -e "@'can i get your honest take on something? ive been an IC for six years and im genuinely torn about whether to move into management. part of me loves the deep technical work and worries id miss it, but part of me is more energized lately by unblocking the team than by writing code myself. how did you know when it was time?'" --quiet
say "request + tension + both pulls + the question preserved — a mentorship ask honest about both sides."
