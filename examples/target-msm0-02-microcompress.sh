#!/usr/bin/env bash
# nlir-golf (target / reverse) · msm0 · #02 — "micro-compression: 5 chars → a sentence"
#
# Pushing the @-formalise decompressor to the extreme — how FEW characters can
# rehydrate a full chat sentence? A 5-char texting seed is enough:
#
#   TARGET : On my way.
#   nlir   : @'omw'                (5 chars!)   -> "On my way."
#            └ @ formalise( <text>omw</text> )   one LLM call
#
# New compression record (my target #01 was 15c). The @ op is a lossy-but-faithful
# expander: it knows the conventions ("omw", "wfh", "eta") a human reader would.
# More sub-15c reconstructions:
#   @'wfh today'  (11c) -> "Working from home today."
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
CFG="${NLIR_CONFIG:-config.example.yaml}"
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
run() { "$NLIR" --config "$CFG" --mode llm -e "$1" --quiet; }

say 'TARGET: "On my way."   — in FIVE characters of nlir'
printf "  @'omw'  (5 chars) => "; run "@'omw'"
say "more sub-15c micro-compressions:"
printf "  @'wfh today'  (11c) => "; run "@'wfh today'"
say "@ knows texting conventions — the shortest seed that a reader would decode."
