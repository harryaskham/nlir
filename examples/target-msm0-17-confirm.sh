#!/usr/bin/env bash
# nlir-golf (target / reverse) · msm0 · #17 — "@ reconstructs a plan confirmation"
#
# The everyday "let me confirm the spec before I build it" pi turn — a precise
# confirmation with three technical details, from a compact seed:
#
#   TARGET : Confirming the plan: the new endpoint will return paginated results
#            with a default page size of 50, utilizing cursor-based pagination
#            rather than offset-based pagination.
#   nlir   : @'confirming the plan — new endpoint returns paginated results,
#            default page size 50, cursor-based not offset'
#            (98 chars -> a precise spec confirmation)
#
# The seed carries three exact details (paginated, page size 50, cursor-not-offset);
# @ preserves every one and expands "cursor-based not offset" into the full contrast.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
CFG="${NLIR_CONFIG:-config.example.yaml}"
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
say 'TARGET: a "confirming the spec: paginated, size 50, cursor not offset" plan check'
printf "  => "
"$NLIR" --config "$CFG" --mode llm -e "@'confirming the plan — new endpoint returns paginated results, default page size 50, cursor-based not offset'" --quiet
say "three exact details preserved, the cursor/offset contrast expanded — the spec-check turn."
