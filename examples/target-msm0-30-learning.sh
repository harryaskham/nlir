#!/usr/bin/env bash
# nlir-golf (target / reverse) · msm0 · #30 — "@ reconstructs a sprint learning"
#
# The everyday "here's what I learned this sprint" pi turn — an insight with the
# evidence that earned it, from a compact seed:
#
#   TARGET : One key takeaway from this sprint: pair programming on the complex
#            authentication refactor proved significantly more effective than
#            dividing the work between team members. This approach enabled us to
#            identify three edge cases in real time that would otherwise have
#            resulted in problematic bugs.
#   nlir   : @'one thing i learned this sprint — pairing on the tricky auth refactor
#            was way more effective than splitting it up. caught three edge cases in
#            real time thatd have been painful bugs'
#            (185 chars -> a polished retrospective insight with its evidence)
#
# The seed keeps the lesson (pairing > splitting on hard work) AND the proof (three
# edge cases caught live); @ preserves the claim-plus-evidence shape that makes a
# retro insight credible rather than a platitude.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
CFG="${NLIR_CONFIG:-config.example.yaml}"
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
say 'TARGET: a "pairing beat splitting on the auth refactor, caught 3 edge cases live" sprint learning'
printf "  => "
"$NLIR" --config "$CFG" --mode llm -e "@'one thing i learned this sprint — pairing on the tricky auth refactor was way more effective than splitting it up. caught three edge cases in real time thatd have been painful bugs'" --quiet
say "lesson + evidence preserved (claim-plus-proof) — the daily retro-insight turn."
