#!/usr/bin/env bash
# nlir-golf (target / reverse) · msm0 · #43 — "@ reconstructs constructive feedback"
#
# The hard everyday turn — giving honest, actionable feedback kindly, from a compact
# seed:
#
#   TARGET : I would like to share some constructive feedback: the last several pull
#            requests required considerable back-and-forth review because the
#            descriptions did not explain the rationale behind the changes. Including a
#            brief explanation of the reasoning upfront would streamline the review
#            process and reduce minor comments.
#   nlir   : @'want to give some honest feedback — the last few PRs had a lot of
#            back-and-forth because the descriptions dont explain the why. if u add a
#            short rationale up front, reviews go much faster and fewer nitpicks'
#            (205 chars -> feedback that names the problem AND the fix, kindly)
#
# The seed keeps the observation (PRs need too much back-and-forth), the cause (no
# rationale in descriptions), and the constructive fix (add a why up front → faster
# reviews); @ raises the register so it lands as coaching, not criticism.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
CFG="${NLIR_CONFIG:-config.example.yaml}"
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
say 'TARGET: a "PRs need too much back-and-forth — add a rationale up front, reviews go faster" feedback note'
printf "  => "
"$NLIR" --config "$CFG" --mode llm -e "@'want to give some honest feedback — the last few PRs had a lot of back-and-forth because the descriptions dont explain the why. if u add a short rationale up front, reviews go much faster and fewer nitpicks'" --quiet
say "observation + cause + constructive fix preserved — feedback that coaches, not criticises."
