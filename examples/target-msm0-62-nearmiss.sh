#!/usr/bin/env bash
# nlir-golf (target / reverse) · msm0 · #62 — "@ reconstructs a near-miss report"
#
# The mature engineering turn — surfacing something that almost went wrong so the team learns
# from it, from a compact seed:
#
#   TARGET : This is to notify you of an issue that could have had significant consequences:
#            our backup job failed silently for the past four days. The failure was only
#            identified because a restore test happened to be performed this morning. No data
#            was lost as a result; however, had an actual incident occurred during that window,
#            we would have had no valid recovery point available. I have since implemented
#            monitoring to ensure this type of failure cannot occur silently again.
#   nlir   : @'quick heads up on something that couldve been bad: our backup job silently
#            failed for the last four days, and we only caught it because someone happened to
#            test a restore this morning. nothing was lost, but if wed had a real incident in
#            that window wed have had no recovery point. ive added a monitor so this cant fail
#            silently again'
#            (330 chars -> a near-miss: the danger / how we caught it / the impact-that-wasnt / the fix)
#
# The seed keeps the danger (backup silently failed 4 days), the luck (caught by a chance
# restore test), the honest impact (nothing lost, but no recovery point if it had mattered),
# and the fix (added monitoring); @ raises the register while keeping the candor — a near-miss
# report earns trust by being honest about how close it was, and @ keeps that honesty.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
CFG="${NLIR_CONFIG:-config.example.yaml}"
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
say 'TARGET: a "backups silently failed 4 days, caught by a chance restore test, nothing lost, monitor added" near-miss'
printf "  => "
"$NLIR" --config "$CFG" --mode llm -e "@'quick heads up on something that couldve been bad: our backup job silently failed for the last four days, and we only caught it because someone happened to test a restore this morning. nothing was lost, but if wed had a real incident in that window wed have had no recovery point. ive added a monitor so this cant fail silently again'" --quiet
say "danger + how-caught + impact-that-wasn't + fix preserved — a near-miss report that's honest about how close."
