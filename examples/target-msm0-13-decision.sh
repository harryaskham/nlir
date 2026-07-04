#!/usr/bin/env bash
# nlir-golf (target / reverse) · msm0 · #13 — "@ reconstructs a decision + rationale"
#
# The everyday "I vote for X, here's why" pi turn — a recommendation with its
# trade-off intact:
#
#   TARGET : Option B is the recommended approach. While it requires greater upfront
#            investment, it offers superior scalability and avoids the technical debt
#            associated with Option A.
#   nlir   : @'go with option B — more upfront work but scales better, avoids the
#            tech debt of A'
#            (78 chars -> a polished recommendation with the trade-off preserved)
#
# The seed carries the verdict + the "more work BUT scales / avoids debt" trade;
# @ keeps the concessive structure (the "while… it…"), not just the conclusion.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
CFG="${NLIR_CONFIG:-config.example.yaml}"
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
say 'TARGET: a "go with option B, here is the trade-off" recommendation'
printf "  => "
"$NLIR" --config "$CFG" --mode llm -e "@'go with option B — more upfront work but scales better, avoids the tech debt of A'" --quiet
say "@ preserves the concessive trade-off (while… it…), not just the verdict."
