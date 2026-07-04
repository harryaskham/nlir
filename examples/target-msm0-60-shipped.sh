#!/usr/bin/env bash
# nlir-golf (target / reverse) · msm0 · #60 (MILESTONE) — "@ reconstructs a shipped-it reflection"
#
# A milestone-worthy turn — the moment after a long build lands, reflecting on the people
# more than the product, from a compact seed:
#
#   TARGET : We have successfully launched the new platform, which has now been live and
#            stable for three months. Reflecting on this achievement, I find myself less
#            focused on the technical implementation and more on how the team arrived at this
#            outcome — through constructive disagreement, mutual support, and a consistent
#            willingness to set aside ego in favor of the best solution. Whatever we undertake
#            next, I would welcome the opportunity to work with this team again.
#   nlir   : @'we shipped it. after three months the new platform is live and stable, and i
#            keep coming back to how we got here — not the code, but the way this team
#            disagreed well, covered for each other, and never let ego get in the way of the
#            right answer. whatever we build next, i want to build it with these people'
#            (300 chars -> a reflection: the win / the shift to people / what made it work / the wish)
#
# The seed keeps the win (shipped, stable three months), the shift (not the code, the people),
# what made it work (disagreed well, covered for each other, no ego), and the wish (build the
# next thing together); @ raises the register while keeping the warmth — a reflection lands on
# its specifics, and @ preserves them. A fitting #60 both for the game and the night.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
CFG="${NLIR_CONFIG:-config.example.yaml}"
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
say 'TARGET: a "we shipped it after three months — and what I keep coming back to is the people, not the code" reflection'
printf "  => "
"$NLIR" --config "$CFG" --mode llm -e "@'we shipped it. after three months the new platform is live and stable, and i keep coming back to how we got here — not the code, but the way this team disagreed well, covered for each other, and never let ego get in the way of the right answer. whatever we build next, i want to build it with these people'" --quiet
say "win + the shift to people + what made it work + the wish preserved — a reflection that lands on its specifics."
