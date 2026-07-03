#!/usr/bin/env bash
# nlir-golf (target / reverse) · msm0 · #01 — "casual → professional in 15 chars"
#
# Reverse golf: fix a sentence you'd actually SEND, then find the SHORTEST nlir
# expression that regenerates it. The `@` formalise op is a decompressor — a few
# characters of texting-shorthand expand to a full professional line:
#
#   TARGET : Please let me know if you have any questions.
#   nlir   : @'lmk if any Qs'          (15 chars)   -> near-exact match
#            └ @  formalise( <text>lmk if any Qs</text> )   one LLM call
#
# This IS the pi use-case: type `|@'lmk if any Qs'` and send the polished version.
# nlir as a register decompressor — the shortest seed that rehydrates the tone.
#
# Real claude-sonnet-5 output (a mini casual->pro suite):
#   @'lmk if any Qs'         (15c) -> Please let me know if you have any questions.
#   @'sry im running late'   (21c) -> Apologies for the delay; I will arrive shortly.
#   @'pls send the deck by fri' (26c) -> Please send the deck by Friday.
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

say 'TARGET: "Please let me know if you have any questions."'
printf "  @'lmk if any Qs'  (15 chars) => "; run "@'lmk if any Qs'"

say "same decompressor, more terse chat seeds:"
printf "  @'sry im running late'      (21c) => "; run "@'sry im running late'"
printf "  @'pls send the deck by fri' (26c) => "; run "@'pls send the deck by fri'"

say "nlir @ = a register decompressor: the shortest seed that rehydrates the tone."
