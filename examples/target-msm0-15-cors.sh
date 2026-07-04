#!/usr/bin/env bash
# nlir-golf (target / reverse) · msm0 · #15 — "@ reconstructs a debugging ask"
#
# The everyday "here's my bug, here's what I tried" pi turn — a debugging question
# with an acronym and a "what am I missing" hedge, from a compact seed:
#
#   TARGET : I am encountering a CORS error when calling the API from the frontend,
#            despite having already added the Access-Control-Allow-Origin header.
#            I am uncertain what additional configuration might be missing.
#   nlir   : @'getting CORS error calling API from frontend even tho i added the
#            allow-origin header, not sure what im missing'
#            (110 chars -> a clear debugging question, acronym expanded)
#
# @ expands "CORS" to its full name, normalises "allow-origin" to the real header,
# and keeps the "not sure what I'm missing" as a proper hedge — symptom, attempt,
# uncertainty, all intact.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
CFG="${NLIR_CONFIG:-config.example.yaml}"
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
say 'TARGET: a "CORS error, tried the header, what am I missing" debugging ask'
printf "  => "
"$NLIR" --config "$CFG" --mode llm -e "@'getting CORS error calling API from frontend even tho i added the allow-origin header, not sure what im missing'" --quiet
say "symptom + attempt + hedge preserved, acronym expanded — the daily debugging turn."
