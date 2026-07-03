#!/usr/bin/env bash
# nlir-golf (target / reverse) · msm0 · #06 — "@ scales: a full reply from a seed"
#
# The @-decompressor isn't just for one-liners — a compact casual seed rehydrates
# a full MULTI-SENTENCE professional reply, every detail preserved:
#
#   TARGET : Thank you for the update. I have reviewed the changes and they look
#            good to me. Please proceed with the merge, and feel free to reach out
#            if you would like a second reviewer to weigh in.
#   nlir   : @'thx, reviewed the changes, lgtm, merge away, ping if u want a 2nd reviewer'
#            (68 chars -> ~190 chars, 3 sentences)
#
# The seed carries the FACTS in shorthand; @ supplies the register and connective
# tissue. This is the everyday pi turn: dash off the gist, send the polished reply.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
CFG="${NLIR_CONFIG:-config.example.yaml}"
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
say 'TARGET: a 3-sentence "reviewed, go ahead and merge, ping for a 2nd reviewer" reply'
printf "  => "
"$NLIR" --config "$CFG" --mode llm -e "@'thx, reviewed the changes, lgtm, merge away, ping if u want a 2nd reviewer'" --quiet
say "the seed carries the facts; @ supplies register + connective tissue. The daily pi turn."
