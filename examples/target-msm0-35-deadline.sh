#!/usr/bin/env bash
# nlir-golf (target / reverse) · msm0 · #35 — "@ reconstructs a deadline pushback"
#
# The everyday "we can't hit that date without cutting corners, let's move it" pi
# turn — a pushback with the trade-off and the ask, from a compact seed:
#
#   TARGET : The Friday deadline cannot be met without compromising the quality of
#            testing. I recommend moving the deadline to Monday, which will allow the
#            weekend as buffer time to complete the work properly rather than shipping
#            a fragile solution.
#   nlir   : @'cant hit friday without cutting testing corners — lets push to monday
#            so the weekend gives buffer to do it properly instead of shipping
#            something fragile'
#            (153 chars -> a polished deadline pushback with the quality rationale)
#
# The seed keeps the constraint (can't hit Friday cleanly), the ask (push to Monday),
# and the why (do it properly vs fragile); @ frames it as a recommendation and keeps
# the "properly rather than fragile" contrast that justifies the slip.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
CFG="${NLIR_CONFIG:-config.example.yaml}"
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
say 'TARGET: a "can'\''t hit Friday without cutting testing, push to Monday to do it right" pushback'
printf "  => "
"$NLIR" --config "$CFG" --mode llm -e "@'cant hit friday without cutting testing corners — lets push to monday so the weekend gives buffer to do it properly instead of shipping something fragile'" --quiet
say "constraint + ask + quality rationale preserved — the daily deadline-pushback turn."
