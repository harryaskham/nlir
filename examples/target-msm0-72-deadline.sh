#!/usr/bin/env bash
# nlir-golf (target / reverse) · msm0 · #72 — "@ reconstructs a deadline negotiation"
#
# The turn that protects both the product and your credibility — pushing back on a deadline with a
# concrete counter rather than a flat no, from a compact seed:
#
#   TARGET : I would like to be transparent about the timeline before we commit to it externally.
#            Completing the full feature by the end of the month is not realistic without cutting
#            corners that I believe should not be cut. What I can commit to is a solid minimum viable
#            product—covering the core flow without edge cases—by month-end, with polish and edge-case
#            handling to follow two weeks later. I would rather commit to that and deliver than promise
#            more than we can achieve and subsequently miss the deadline.
#   nlir   : @'i want to be honest about the timeline before we commit to it externally. building the
#            full feature by end of month isnt realistic without cutting corners i dont think we should
#            cut. what i can commit to is a solid MVP — core flow, no edge cases — by month-end, with
#            the polish and edge handling following two weeks later. id rather promise that and deliver
#            it than promise the moon and slip'
#            (388 chars -> a realistic counter: the honesty / the constraint / the concrete offer / the principle)
#
# The seed keeps the honesty (before we commit externally), the constraint (full feature isn't
# realistic without bad corner-cutting), the concrete counter (MVP core flow by month-end, polish +2wk),
# and the principle (rather promise-and-deliver than promise-the-moon-and-slip); @ raises the register
# while keeping the spine — a deadline pushback lands when it offers a real alternative, and @ keeps it.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
CFG="${NLIR_CONFIG:-config.example.yaml}"
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
say 'TARGET: a "full feature by month-end isn'\''t realistic without bad corner-cutting — I can commit to a solid MVP now, polish +2wk" counter'
printf "  => "
"$NLIR" --config "$CFG" --mode llm -e "@'i want to be honest about the timeline before we commit to it externally. building the full feature by end of month isnt realistic without cutting corners i dont think we should cut. what i can commit to is a solid MVP — core flow, no edge cases — by month-end, with the polish and edge handling following two weeks later. id rather promise that and deliver it than promise the moon and slip'" --quiet
say "honesty + constraint + concrete offer + principle preserved — a deadline pushback that offers a real alternative."
