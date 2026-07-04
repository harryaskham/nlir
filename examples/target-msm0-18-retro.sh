#!/usr/bin/env bash
# nlir-golf (target / reverse) · msm0 · #18 — "@ reconstructs a demo retro"
#
# The everyday "here's how the demo went, here's the takeaway" pi turn — praise +
# a concern + an action item, from a compact seed:
#
#   TARGET : The demonstration was highly successful, and the client was impressed
#            with the search performance. However, one concern was raised regarding
#            mobile responsiveness, which we should prioritize during the next sprint.
#   nlir   : @'demo went really well, client impressed with search speed; one concern
#            was mobile responsiveness so lets prioritize that next sprint'
#            (128 chars -> a polished retro with a "however" pivot)
#
# The seed carries three beats (went well / one concern / the action); @ keeps the
# positive-then-caveat structure (the "however"), preserving the retro's shape.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
CFG="${NLIR_CONFIG:-config.example.yaml}"
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
say 'TARGET: a "demo went well, one concern, prioritize it next sprint" retro'
printf "  => "
"$NLIR" --config "$CFG" --mode llm -e "@'demo went really well, client impressed with search speed; one concern was mobile responsiveness so lets prioritize that next sprint'" --quiet
say "praise + concern + action preserved, the 'however' pivot kept — the daily retro turn."
