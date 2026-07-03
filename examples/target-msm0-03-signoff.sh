#!/usr/bin/env bash
# nlir-golf (target / reverse) · msm0 · #03 — "chat sign-offs from a few chars"
#
# The @-formalise decompressor on everyday chat CLOSERS — the throwaway lines you
# end a message with. A handful of chars → the polished version:
#
#   TARGET : Thank you very much.
#   nlir   : @'thx a ton'          (10 chars)   -> "Thank you very much."
#
# @ knows the register: casual gratitude -> professional gratitude, no more info
# than the seed carries. Complements target #02 (@'omw' -> "On my way.").
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

say 'TARGET: "Thank you very much."'
printf "  @'thx a ton'  (10 chars) => "; run "@'thx a ton'"
say "a professional sign-off from a texting seed — the @ register decompressor."
