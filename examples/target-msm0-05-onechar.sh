#!/usr/bin/env bash
# nlir-golf (target / reverse) · msm0 · #05 — "the compression floor: 1 char"
#
# How few characters can regenerate a full acknowledgment? ONE:
#
#   TARGET : Understood.
#   nlir   : @'k'                  (1 char!)   -> "Understood."
#
# A single letter that a reader decodes ("k" = "ok" = acknowledged). This is the
# floor of the @-decompressor game — you cannot go below one character, and one
# character still round-trips to a complete, sendable sentence.
#
#   @'ok' (2c) -> "Understood."   (same target, one char more)
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

say 'TARGET: "Understood."   — in ONE character'
printf "  @'k'   (1 char) => "; run "@'k'"
printf "  @'ok'  (2 char) => "; run "@'ok'"
say "the compression floor: one letter still round-trips to a full sentence."
