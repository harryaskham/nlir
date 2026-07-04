#!/usr/bin/env bash
# nlir-golf (target / reverse) · msm0 · #52 — "@ reconstructs a velocity concern"
#
# The everyday "I've noticed a problem and here's my read + a fix to discuss" pi turn —
# a diagnosis with a proposal, from a compact seed:
#
#   TARGET : I believe our velocity is declining due to excessive context-switching
#            between platform work and feature requests. I would like to discuss options
#            for protecting focus time or separating these two workstreams.
#   nlir   : @'i think our velocity is dropping because were context-switching too much
#            between platform work and feature requests. id like to talk about protecting
#            focus time or splitting the two streams'
#            (186 chars -> a measured concern with a hypothesis and two options)
#
# The seed keeps the observation (velocity dropping), the hypothesis (too much
# context-switching between two streams), and the two proposals (protect focus time OR
# split the streams); @ frames it as a considered concern to discuss — not a complaint,
# a diagnosis with next steps.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
CFG="${NLIR_CONFIG:-config.example.yaml}"
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
say 'TARGET: a "velocity is dropping from context-switching — protect focus time or split the streams?" concern'
printf "  => "
"$NLIR" --config "$CFG" --mode llm -e "@'i think our velocity is dropping because were context-switching too much between platform work and feature requests. id like to talk about protecting focus time or splitting the two streams'" --quiet
say "observation + hypothesis + two options preserved — a diagnosis with next steps, not a complaint."
