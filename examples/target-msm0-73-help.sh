#!/usr/bin/env bash
# nlir-golf (target / reverse) · msm0 · #73 — "@ reconstructs asking for help"
#
# The turn that takes more courage than it should — admitting you're stuck and asking for a hand,
# from a compact seed:
#
#   TARGET : I have spent the past two days investigating this bug without success. The race condition
#            manifests only in the production environment and does not reproduce locally, and I have
#            already eliminated the most obvious potential causes. I am hesitant to ask for help, but I
#            believe a second perspective would be valuable before I spend another day on this issue.
#            Would you have 30 minutes today to review it together?
#   nlir   : @'ive been staring at this bug for two days and im out of ideas — the race condition only
#            shows up in prod, never locally, and ive ruled out the obvious causes. i hate asking, but i
#            think i need a second pair of eyes before i burn another day on it. would you have 30
#            minutes to pair on it sometime today?'
#            (297 chars -> a good ask for help: the effort / the specifics / the honesty / the concrete request)
#
# The seed keeps the effort already spent (two days, obvious causes ruled out), the specifics (race
# condition, prod-only, not local), the honesty (I hate asking), and the concrete ask (30 min to pair
# today); @ raises the register while keeping the candor — a request for help lands when it shows the
# work done first, and @ keeps the effort and the specifics front and centre.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
CFG="${NLIR_CONFIG:-config.example.yaml}"
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
say 'TARGET: a "two days on this prod-only race condition, ruled out the obvious, hate asking but need a second pair of eyes — 30 min today?" ask'
printf "  => "
"$NLIR" --config "$CFG" --mode llm -e "@'ive been staring at this bug for two days and im out of ideas — the race condition only shows up in prod, never locally, and ive ruled out the obvious causes. i hate asking, but i think i need a second pair of eyes before i burn another day on it. would you have 30 minutes to pair on it sometime today?'" --quiet
say "effort + specifics + honesty + concrete request preserved — an ask for help that shows the work done first."
