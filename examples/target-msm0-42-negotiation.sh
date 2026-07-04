#!/usr/bin/env bash
# nlir-golf (target / reverse) · msm0 · #42 — "@ reconstructs a salary negotiation"
#
# A delicate everyday turn — countering an offer graciously with two paths, from a
# compact seed:
#
#   TARGET : Thank you for the offer. As the base salary is somewhat below my target,
#            I would welcome the opportunity to discuss either increasing it by
#            approximately 10% or incorporating equity to help bridge the gap.
#   nlir   : @'thanks for the offer — the base is a little below my target, so id love
#            to explore either bumping it about 10% or adding equity to bridge the gap'
#            (145 chars -> a polished, gracious negotiation counter with two options)
#
# The seed keeps the gratitude, the gap (base below target), and the two paths (10%
# bump OR equity); @ raises the register while keeping the collaborative "either/or"
# framing — a counter that opens a conversation rather than making a demand.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
CFG="${NLIR_CONFIG:-config.example.yaml}"
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
say 'TARGET: a "thanks for the offer, base is below target, could we do +10% or equity?" negotiation'
printf "  => "
"$NLIR" --config "$CFG" --mode llm -e "@'thanks for the offer — the base is a little below my target, so id love to explore either bumping it about 10% or adding equity to bridge the gap'" --quiet
say "gratitude + the gap + two paths preserved — a counter that opens a conversation, not a demand."
