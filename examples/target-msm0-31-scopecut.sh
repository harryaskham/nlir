#!/usr/bin/env bash
# nlir-golf (target / reverse) · msm0 · #31 — "@ reconstructs a scope-cut proposal"
#
# The everyday "let's cut X to ship, fast-follow later" pi turn — a prioritization
# call with the reasoning, from a compact seed:
#
#   TARGET : Given the current timeline, I recommend excluding the analytics
#            dashboard from the v1 release and prioritizing delivery of the core
#            booking flow. Analytics can be addressed in a subsequent release, at
#            which point real usage data will also be available to inform its design.
#   nlir   : @'given the timeline i think we should cut the analytics dashboard from
#            v1 and ship the core booking flow first. can fast-follow with analytics
#            once we have real usage data to design around anyway'
#            (194 chars -> a polished scope-cut proposal with the fast-follow rationale)
#
# The seed keeps the cut (analytics out of v1), the priority (core booking first),
# and the silver lining (fast-follow with real data); @ preserves that "and actually
# it's better later" reasoning that turns a cut into a plan.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
CFG="${NLIR_CONFIG:-config.example.yaml}"
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
say 'TARGET: a "cut analytics from v1, ship core booking, fast-follow with real data" scope proposal'
printf "  => "
"$NLIR" --config "$CFG" --mode llm -e "@'given the timeline i think we should cut the analytics dashboard from v1 and ship the core booking flow first. can fast-follow with analytics once we have real usage data to design around anyway'" --quiet
say "cut + priority + fast-follow rationale preserved — the daily scope-cut turn."
