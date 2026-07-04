#!/usr/bin/env bash
# nlir-golf (target / reverse) · msm0 · #11 — "@ reconstructs a bug report"
#
# The daily "here's what's broken" pi turn — a structured bug report from a casual
# seed, every fact preserved (browser, symptom set, what works):
#
#   TARGET : The export button is not functioning in Safari. Clicking it produces
#            no visible response, error message, or file download. The feature
#            operates as expected in Chrome.
#   nlir   : @'export button broken on safari — click does nothing, no error,
#            no download; works in chrome'
#            (89 chars -> a clean 3-sentence bug report)
#
# @ turns telegraphic symptoms into report prose while keeping every detail:
# affected browser, the three null symptoms, and the working control case.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
CFG="${NLIR_CONFIG:-config.example.yaml}"
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
say 'TARGET: a 3-sentence "export button broken on Safari, works on Chrome" bug report'
printf "  => "
"$NLIR" --config "$CFG" --mode llm -e "@'export button broken on safari — click does nothing, no error, no download; works in chrome'" --quiet
say "telegraphic symptoms -> report prose, every detail kept — the daily bug-report turn."
