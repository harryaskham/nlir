#!/usr/bin/env bash
# nlir-golf (target / reverse) · msm0 · #50 — "@ reconstructs a team reflection"
#
# A milestone-worthy turn — reflecting on a project's meaning, from a compact seed:
#
#   TARGET : This has been the most rewarding project I have had the privilege of
#            working on. This is not because it was without challenges — it certainly
#            was not — but because of the manner in which we navigated those challenges
#            together: with honesty, without ego, and with unwavering mutual support.
#            Thank you all.
#   nlir   : @'this has been the best project ive worked on. not because it was easy —
#            it wasnt — but because of how we handled the hard parts together: honestly,
#            without ego, and always with each others backs. thank you all'
#            (207 chars -> a heartfelt reflection keeping the "not X but Y" turn + the values)
#
# The seed keeps the shape (best project — not because easy, but because of HOW we
# worked) and the three values (honesty / no ego / mutual support); @ raises the
# register while keeping the warmth — a reflection lands because of its specifics and
# its structure, not its polish, and @ preserves both.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
CFG="${NLIR_CONFIG:-config.example.yaml}"
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
say 'TARGET: a "best project I have worked on — not because it was easy, but how we handled it together" reflection'
printf "  => "
"$NLIR" --config "$CFG" --mode llm -e "@'this has been the best project ive worked on. not because it was easy — it wasnt — but because of how we handled the hard parts together: honestly, without ego, and always with each others backs. thank you all'" --quiet
say "the 'not because easy, but how we worked' shape + the three values preserved — a reflection that lands."
