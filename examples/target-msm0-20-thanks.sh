#!/usr/bin/env bash
# nlir-golf (target / reverse) · msm0 · #20 — "@ reconstructs a note of appreciation"
#
# Not every pi turn is a request — sometimes it's thanks. A warm, specific note of
# appreciation from a compact seed:
#
#   TARGET : I would like to express my appreciation for your swift response to last
#            night's incident. Isolating the root cause and deploying a fix within
#            the hour was an impressive achievement. Thank you for your efforts.
#   nlir   : @'really appreciate you jumping on that incident so fast last night —
#            isolating the root cause and shipping a fix within the hour was
#            impressive, thank you'
#            (148 chars -> a polished, specific thank-you)
#
# The seed keeps the SPECIFICS (the incident, the root-cause isolation, the
# one-hour fix); @ raises the register without hollowing out the praise into
# generic thanks — the detail is what makes recognition land.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
CFG="${NLIR_CONFIG:-config.example.yaml}"
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
say 'TARGET: a specific "thanks for jumping on the incident so fast" note'
printf "  => "
"$NLIR" --config "$CFG" --mode llm -e "@'really appreciate you jumping on that incident so fast last night — isolating the root cause and shipping a fix within the hour was impressive, thank you'" --quiet
say "the specifics preserved (incident / root cause / one-hour fix) — recognition that lands."
