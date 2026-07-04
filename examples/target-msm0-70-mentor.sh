#!/usr/bin/env bash
# nlir-golf (target / reverse) · msm0 · #70 (MILESTONE) — "@ reconstructs mentor gratitude"
#
# A milestone-worthy turn — the thank-you you owe the person who shaped how you work, from a
# compact seed:
#
#   TARGET : I do not believe I ever properly expressed my gratitude to you. A great deal of how I
#            approach my work — the way I weigh tradeoffs, how I conduct a review, even how I voice
#            disagreement — I learned from observing you. You entrusted me with difficult problems
#            before I felt ready for them, and you supported me when I faltered. Whatever I have
#            become as an engineer, you have played a significant part in that. Thank you.
#   nlir   : @'i dont think i ever properly thanked you. a lot of how i work — the way i think about
#            tradeoffs, how i run a review, even how i disagree — i learned watching you. you gave me
#            hard problems before i thought i was ready, and backed me when i stumbled. whatever ive
#            become as an engineer, youre a big part of it. thank you'
#            (330 chars -> gratitude with substance: the admission / the specifics / the risk they took / the credit)
#
# The seed keeps the honest admission (never properly thanked you), the specifics of what was learned
# (tradeoffs, reviews, how to disagree), the risk they took (hard problems before I was ready, backed
# me when I stumbled), and the credit (you're a big part of who I've become); @ raises the register
# while keeping the warmth — gratitude lands on its specifics, and @ preserves every one. Fitting for
# #70, and for a night's work built on exactly this kind of backing-each-other.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
CFG="${NLIR_CONFIG:-config.example.yaml}"
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
say 'TARGET: a "I never properly thanked you — I learned how I work from watching you, you backed me before I was ready" thank-you'
printf "  => "
"$NLIR" --config "$CFG" --mode llm -e "@'i dont think i ever properly thanked you. a lot of how i work — the way i think about tradeoffs, how i run a review, even how i disagree — i learned watching you. you gave me hard problems before i thought i was ready, and backed me when i stumbled. whatever ive become as an engineer, youre a big part of it. thank you'" --quiet
say "admission + specifics + the risk they took + the credit preserved — gratitude that lands on its specifics."
