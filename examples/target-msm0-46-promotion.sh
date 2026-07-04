#!/usr/bin/env bash
# nlir-golf (target / reverse) · msm0 · #46 — "@ reconstructs a promotion recommendation"
#
# A high-stakes everyday turn — putting someone forward, with the evidence, from a
# compact seed:
#
#   TARGET : I would like to nominate you for the senior role. Over the past two
#            quarters, you have consistently led the most challenging projects,
#            mentored two junior colleagues, and elevated the standard of code quality
#            across the team. You have been operating at that level of performance for
#            some time now, and it is time for your title to reflect this.
#   nlir   : @'i want to put you forward for the senior role. over the last two quarters
#            youve consistently led the hardest projects, mentored two juniors, and
#            raised the bar on code quality. youve been operating at that level for a
#            while — its time the title caught up'
#            (243 chars -> a polished nomination: the ask + three concrete proofs + the case)
#
# The seed keeps the ask (senior role) and the THREE concrete proofs (led hard
# projects / mentored juniors / raised code quality) plus the case ("already operating
# at that level"); @ raises the register while keeping every specific — a nomination is
# only as strong as its evidence.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
CFG="${NLIR_CONFIG:-config.example.yaml}"
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
say 'TARGET: a "putting you forward for senior — led hard projects, mentored juniors, raised quality" nomination'
printf "  => "
"$NLIR" --config "$CFG" --mode llm -e "@'i want to put you forward for the senior role. over the last two quarters youve consistently led the hardest projects, mentored two juniors, and raised the bar on code quality. youve been operating at that level for a while — its time the title caught up'" --quiet
say "the ask + three concrete proofs + the case preserved — a nomination that's only as strong as its evidence."
