#!/usr/bin/env bash
# nlir-golf (target / reverse) · msm0 · #04 — "3-char compression record"
#
# The shortest seed that still decodes to a full sentence. Three characters:
#
#   TARGET : I will be back shortly.
#   nlir   : @'brb'                (3 chars!)   -> "I will be back shortly."
#
# New record (was @'omw' at 5c). Works because "brb" is an UNAMBIGUOUS convention.
# Boundary of the trick: ambiguous seeds miss — e.g. @'ooo' formalises to "Ooh…"
# not "out of office", since @ can't disambiguate the intent from 3 letters. The
# seed has to be decodable by a human reader; that's the real compression floor.
#
# Also: @'ttyl' (4c) -> "Talk to you later."
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

say 'TARGET: "I will be back shortly."   — in THREE characters'
printf "  @'brb'  (3 chars) => "; run "@'brb'"
say "more:"
printf "  @'ttyl' (4c) => "; run "@'ttyl'"
say "3 chars, one sentence. The floor: the seed must be decodable by a reader."
