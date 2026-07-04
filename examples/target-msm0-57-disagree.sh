#!/usr/bin/env bash
# nlir-golf (target / reverse) · msm0 · #57 — "@ reconstructs a principled disagreement"
#
# The high-stakes "I hear you, but no — and here's why" turn: disagreeing up, with a reason
# that outweighs the pressure, from a compact seed:
#
#   TARGET : I understand the desire to ship on Friday; however, I do not believe we should
#            proceed. We currently have two unresolved data-loss bugs, and releasing with
#            these issues poses a greater risk to customer trust than a one-week delay
#            would. I would prefer to postpone the release date rather than ship a product
#            that risks corrupting customer data.
#   nlir   : @'i hear you on wanting to ship friday but i dont think we should. we still
#            have two open data-loss bugs, and shipping with those is a bigger risk to trust
#            than a weeks delay. id rather slip the date than ship something that corrupts
#            customer data'
#            (238 chars -> a principled no: the acknowledgment / the position / the reason / the line)
#
# The seed keeps the acknowledgment (I hear you on Friday), the position (I don't think we
# should), the reason (two data-loss bugs > a week's delay), and the line (I'd rather slip
# than corrupt data); @ raises the register into a firm-but-respectful disagreement — the
# reason carries it, and @ keeps the reason central rather than softening it away.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
CFG="${NLIR_CONFIG:-config.example.yaml}"
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
say 'TARGET: an "I hear you on Friday, but no — two data-loss bugs outweigh a week'\''s delay" principled no'
printf "  => "
"$NLIR" --config "$CFG" --mode llm -e "@'i hear you on wanting to ship friday but i dont think we should. we still have two open data-loss bugs, and shipping with those is a bigger risk to trust than a weeks delay. id rather slip the date than ship something that corrupts customer data'" --quiet
say "acknowledgment + position + reason + line preserved — a disagreement that leads with the reason."
