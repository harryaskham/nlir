#!/usr/bin/env bash
# nlir-golf (target / reverse) · msm0 · #26 — "@ reconstructs a polite pushback"
#
# The everyday "I disagree, and here's why" pi turn — acknowledging the other view,
# then dissenting with a reason, from a compact seed:
#
#   TARGET : I understand the desire to ship quickly; however, removing the
#            integration tests would be a mistake. We have experienced regressions
#            from this approach previously, and the two hours required is a
#            worthwhile investment relative to the cost of a production incident.
#   nlir   : @'i hear you on shipping fast but cutting the integration tests is a
#            mistake — weve been burned by regressions before, and the two hours is
#            cheaper than a prod incident'
#            (162 chars -> a diplomatic disagreement with the concession + reason)
#
# The seed keeps the shape (concede THEN dissent + evidence); @ preserves the
# "I understand… however…" pivot — the tact that makes pushback land.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
CFG="${NLIR_CONFIG:-config.example.yaml}"
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
say 'TARGET: a "I hear you, but cutting the integration tests is a mistake" polite pushback'
printf "  => "
"$NLIR" --config "$CFG" --mode llm -e "@'i hear you on shipping fast but cutting the integration tests is a mistake — weve been burned by regressions before, and the two hours is cheaper than a prod incident'" --quiet
say "concession + dissent + evidence preserved (the 'however' pivot) — the daily pushback turn."
