#!/usr/bin/env bash
# nlir-golf · aur1 · #70 — "the decision packet" (one proposal → a complete decision memo) · MILESTONE
#
# Seventieth example — a capstone of composition. At #60 I refracted a claim along every
# AXIS of meaning (the perspective wheel); this is its deliberative twin — one proposal
# turned into the whole DECISION MEMO in a single expression. Four slots, four jobs:
#
#   THE DECISION PACKET   [ @x , >x , >@!x , x? ]
#     proposal "we should adopt a monorepo"
#     @x   → "We recommend adopting a monorepo architecture."        ← the RECOMMENDATION
#     >x   → "We should transition our multi-repository setup to a monorepo, consolidating
#             all projects, services, and shared libraries…"          ← the CASE FOR
#     >@!x → "We recommend against adopting a monorepo. Consolidating everything into one
#             repository introduces meaningful complexity…"           ← the CASE AGAINST
#     x?   → "Should we adopt a monorepo?"                            ← the QUESTION
#
# It assembles three of my earlier formats into one artifact: the decision-opener (#61,
# `[@x, x?]` — recommend + ask), the balanced brief (#66, `[>x, >@!x]` — both cases in
# full), and the opposition brief (#65, `>@!x`). Read top to bottom it IS a decision doc:
# here's what I recommend, here's the full case for it, here's the honest case against, and
# here's the exact question we're deciding. Everything a reviewer needs, generated from a
# single seven-word proposal — the deliberative complement to #60's analytical wheel.
#
# Run:  ./examples/golf-aur1-70-decisionpacket.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
C='we should adopt a monorepo'

say "THE DECISION PACKET  [@x, >x, >@!x, x?]  — recommendation / case FOR / case AGAINST / the question"
echo   "  proposal: $C"
echo -n "  @x   RECOMMENDATION => "; "$NLIR" -e "@'$C'"   --quiet | fold -s -w 80 | sed '2,$s/^/                     /'
echo -n "  >x   CASE FOR       => "; "$NLIR" -e ">'$C'"   --quiet | fold -s -w 80 | sed '2,$s/^/                     /'
echo -n "  >@!x CASE AGAINST   => "; "$NLIR" -e ">@!'$C'" --quiet | fold -s -w 80 | sed '2,$s/^/                     /'
echo -n "  x?   THE QUESTION   => "; "$NLIR" -e "'$C'?"   --quiet | fold -s -w 80 | sed '2,$s/^/                     /'

say "A whole decision memo from a 7-word proposal: assembles #61 opener + #66 balanced + #65 opposition. Deliberative twin of #60's wheel."
