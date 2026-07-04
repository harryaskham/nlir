#!/usr/bin/env bash
# nlir-golf (target / reverse) · msm0 · #32 — "@ reconstructs a resignation note"
#
# A weightier everyday turn — announcing a hard personal decision with grace, from a
# compact seed:
#
#   TARGET : After careful consideration, I have decided to accept the offer from the
#            other company. This was a difficult decision, as I have greatly valued
#            working with this team; however, the new role represents a better fit
#            for my desired professional growth.
#   nlir   : @'after thinking it over im going to accept the offer at the other
#            company. really hard decision because ive loved working with this team,
#            but the new role is a better fit for where i want to grow'
#            (190 chars -> a graceful resignation keeping the warmth + the reason)
#
# The seed keeps the decision, the regret ("loved this team"), and the rationale
# ("better fit for growth"); @ raises the register WITHOUT flattening the warmth —
# on a note like this, the "however I've valued…" is the whole point.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
CFG="${NLIR_CONFIG:-config.example.yaml}"
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
say 'TARGET: a "I have decided to take the other offer — loved this team, but better fit" resignation'
printf "  => "
"$NLIR" --config "$CFG" --mode llm -e "@'after thinking it over im going to accept the offer at the other company. really hard decision because ive loved working with this team, but the new role is a better fit for where i want to grow'" --quiet
say "decision + warmth + rationale preserved — @ raises register without flattening the feeling."
