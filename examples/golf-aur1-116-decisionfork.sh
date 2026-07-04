#!/usr/bin/env bash
# nlir-golf · aur1 · #116 — "the decision fork" (expand BOTH roads, then pose the choice: [>(a|b), (a|b)?])
#
# A genuine fork in the road, laid out for a decision. `[>(a|b), (a|b)?]` takes a real either/or
# and does two things: `>(a|b)` (my #42 fork) expands BOTH options at full detail — because `|`
# is genuine CHOICE, `>` develops each path rather than blending them — and `(a|b)?` (my #15
# disambiguator) poses the clean decision. Here are your two roads, spelled out; now pick one.
#
#   THE DECISION FORK   [ >(a|b) , (a|b)? ]
#     a = "build the analytics dashboard in-house" , b = "buy an off-the-shelf analytics tool"
#     >(a|b) → "…develop it in-house — dedicating engineering, design and data resources to a
#              custom solution tailored to our metrics and integrations … OR buy off-the-shelf —
#              faster to deploy, lower upfront cost, but less tailored…"      ← BOTH PATHS
#     (a|b)? → "Should we build the analytics dashboard in-house or buy an off-the-shelf tool?"
#                                                                             ← THE CHOICE
#
# This is `|` earning its keep as a real decision structure (not just a summary connective, my
# #115). Because `>` INTEGRATES over `&` but FORKS over `|` (#42/#71), grouping the options with
# `|` keeps them as two DISTINCT developed paths instead of one merged blob — exactly what you
# want when the whole point is to CHOOSE. Present the roads, then ask.
#
# NOTE (paren-echo): `>(a|b)` output sometimes carries a stray leading "(" — the cosmetic
# parenthesis-echo I have a fix prototyped for (drop the `( )` wrapper in the Llm eval branch
# only, keeping it for Det). The grouping is load-bearing at PARSE; the echo is purely visual.
#
# Run:  ./examples/golf-aur1-116-decisionfork.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
A='build the analytics dashboard in-house'; B='buy an off-the-shelf analytics tool'

say "THE DECISION FORK  [>(a|b), (a|b)?]  — expand BOTH roads (>(a|b), #42) + pose the choice ((a|b)?, #15)"
echo   "  a: $A"
echo   "  b: $B"
echo -n "  >(a|b) (BOTH PATHS)  => "; "$NLIR" -e ">('$A' | '$B')" --quiet | fold -s -w 80 | sed '2,$s/^/       /'
echo -n "  (a|b)? (THE CHOICE)  => "; "$NLIR" -e "('$A' | '$B')?" --quiet | fold -s -w 80 | sed '2,$s/^/       /'

say "| is genuine CHOICE: > FORKS over | (#42), keeping the paths DISTINCT (vs > INTEGRATES over & #71, which blends). So the fork develops each road, then (a|b)? asks. (Leading '(' = the cosmetic paren-echo; fix prototyped.)"
