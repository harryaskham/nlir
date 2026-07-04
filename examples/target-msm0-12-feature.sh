#!/usr/bin/env bash
# nlir-golf (target / reverse) · msm0 · #12 — "@ reconstructs a feature request"
#
# The everyday "can we add X, here's why" pi turn — a feature request with rationale
# from a compact seed:
#
#   TARGET : Add a dark mode toggle to the settings menu. This feature has been
#            requested by numerous users and would help reduce eye strain for
#            individuals working night shifts.
#   nlir   : @'add dark mode toggle in settings — many users asked, helps eye
#            strain on night shifts'
#            (81 chars -> a polished feature request with justification)
#
# The seed carries the ask + two justifications (demand, benefit); @ turns it into
# a well-formed request with the reasons intact.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
CFG="${NLIR_CONFIG:-config.example.yaml}"
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
say 'TARGET: an "add dark mode, here is why" feature request'
printf "  => "
"$NLIR" --config "$CFG" --mode llm -e "@'add dark mode toggle in settings — many users asked, helps eye strain on night shifts'" --quiet
say "ask + two justifications preserved — the daily feature-request turn."
