#!/usr/bin/env bash
# nlir-golf (target / reverse) · msm0 · #08 — "the status ping"
#
# A one-line "it's ready" status message, reconstructed from a compact seed:
#
#   TARGET : The fix has been deployed to staging and is ready for your review at
#            your earliest convenience.
#   nlir   : @'pushed the fix to staging, ready for u to test whenever'
#            (54 chars -> a polished status line)
#
# The everyday "heads-up, go test it" pi turn — the seed carries the two facts
# (deployed where, ready for what), @ supplies the professional phrasing.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
CFG="${NLIR_CONFIG:-config.example.yaml}"
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
say 'TARGET: "The fix has been deployed to staging and is ready for your review…"'
printf "  => "
"$NLIR" --config "$CFG" --mode llm -e "@'pushed the fix to staging, ready for u to test whenever'" --quiet
say "the daily 'heads-up, go test it' turn — seed carries the facts, @ the phrasing."
