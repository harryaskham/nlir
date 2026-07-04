#!/usr/bin/env bash
# nlir-golf (target / reverse) · msm0 · #38 — "@ reconstructs specific praise"
#
# The everyday "your work was genuinely great, here's exactly why" pi turn — praise
# that names the specifics (the only kind worth sending), from a compact seed:
#
#   TARGET : I wanted to express my appreciation for the API documentation you
#            prepared; it is the clearest I have encountered on this team. The
#            inclusion of examples for every endpoint made integration considerably
#            easier. I would encourage you to continue applying this same approach
#            going forward.
#   nlir   : @'just wanted to say the API docs you wrote are the clearest ive seen on
#            this team — the examples for every endpoint made integrating a breeze.
#            whatever u did there please keep doing it'
#            (178 chars -> polished praise with the specific reason it mattered)
#
# The seed keeps WHAT (the API docs), WHY (per-endpoint examples eased integration),
# and the ask (keep doing it); @ raises the register but keeps the specifics — vague
# praise is worthless, the detail is what makes it land.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
CFG="${NLIR_CONFIG:-config.example.yaml}"
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
say 'TARGET: a "your API docs are the clearest here — the per-endpoint examples, keep it up" praise note'
printf "  => "
"$NLIR" --config "$CFG" --mode llm -e "@'just wanted to say the API docs you wrote are the clearest ive seen on this team — the examples for every endpoint made integrating a breeze. whatever u did there please keep doing it'" --quiet
say "what + why + keep-it-up preserved — specific praise, the only kind worth sending."
