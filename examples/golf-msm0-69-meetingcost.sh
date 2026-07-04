#!/usr/bin/env bash
# nlir-golf · msm0 · #69 — "the meeting cost" (a calculator with a punchline)
#
# nlir as a pocket calculator that talks back. A deterministic three-way product, a literal $,
# and interpolation — the "what is this meeting ACTUALLY costing us?" one-liner:
#
#   people=8 ; hrs=1.5 ; rate=75 ; cost=$people*$hrs*$rate ; "this meeting costs \$$cost — $people people, $hrs hours, at \$$rate/hr"
#   │          │         │         │                         └ template: literal \$ + interpolated fields
#   │          │         │         └ cost = 8 × 1.5 × 75 = 900   (arithmetic, exact)
#   │          │         └ rate=75  \
#   │          └ hrs=1.5           } stored inputs
#   └───────── people=8           /
#
#   =>  this meeting costs $900 — 8 people, 1.5 hours, at $75/hr
#
# cost is computed exactly, `\$` is a LITERAL dollar (the bd-65b737 fix, #51), and the fields
# interpolate. Same deterministic-substrate family as #67's receipt — pointed at the most
# persuasive number in any calendar. No LLM: a calculator that states its own bottom line.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
CFG="${NLIR_CONFIG:-config.example.yaml}"
# deterministic — no key needed

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
say 'THE MEETING COST   people=8;hrs=1.5;rate=75;cost=$people*$hrs*$rate;"this meeting costs \$$cost — …"'
printf '  '; "$NLIR" --config "$CFG" --mode det --quiet -e 'people=8;hrs=1.5;rate=75;cost=$people*$hrs*$rate;"this meeting costs \$$cost — $people people, $hrs hours, at \$$rate/hr"'
say "8 × 1.5 × 75 = 900, computed exactly, with a literal \$ and interpolated fields. A calculator that talks back."
