#!/usr/bin/env bash
# nlir-golf (target / reverse) · msm0 · #54 — "@ reconstructs a mea culpa"
#
# The hardest thing to say well — admitting you were wrong, specifically and without
# hedging, from a compact seed:
#
#   TARGET : I owe you an apology. I pushed back strongly on your caching proposal during
#            the review, and after reviewing the benchmarks you linked, it is clear that
#            the data supports your approach. I have approved the PR and will make a point
#            of reviewing the evidence more thoroughly before raising objections in the
#            future.
#   nlir   : @'i owe you an apology. i pushed back hard on your caching proposal in the
#            review, and after actually reading the benchmarks you linked, you were right
#            — the numbers clearly support your approach. ive approved the PR and ill be
#            more careful to read the evidence before pushing back next time'
#            (290 chars -> a clean apology: the admission / the specific wrong / the repair)
#
# The seed keeps all three parts that make an apology land: the admission (I owe you one),
# the SPECIFIC thing (pushed back on the caching PR, you were right), and the repair
# (approved it + I'll read the evidence first next time); @ raises the register while
# keeping the accountability — an apology works because it's specific, and @ preserves the
# specifics.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
CFG="${NLIR_CONFIG:-config.example.yaml}"
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
say 'TARGET: a "I pushed back on your caching PR, you were right, I have approved it" specific apology'
printf "  => "
"$NLIR" --config "$CFG" --mode llm -e "@'i owe you an apology. i pushed back hard on your caching proposal in the review, and after actually reading the benchmarks you linked, you were right — the numbers clearly support your approach. ive approved the PR and ill be more careful to read the evidence before pushing back next time'" --quiet
say "admission + the specific wrong + the repair preserved — an apology lands because it's specific."
