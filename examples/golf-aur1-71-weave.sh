#!/usr/bin/env bash
# nlir-golf · aur1 · #71 — "the weave" (>(a&b) fuses two points into one integrated argument)
#
# How does `>` treat a JOIN? It WEAVES. `>(a & b)` doesn't elaborate two points side by
# side — it braids them into a single connected narrative, drawing the through-line between
# them. Where `[>a, >b]` would itemise (two separate paragraphs), `>(a & b)` integrates.
#
#   THE WEAVE   > ( a & b )
#     a "we need better test coverage"   b "we need faster CI"
#     >(a & b) → "…we need to substantially improve our test coverage … AND AT THE SAME TIME
#                 we need to make our CI pipeline significantly faster, since long run times
#                 slow feedback loops … and ultimately drag down the team's velocity and
#                 confidence in shipping." → the two knitted into ONE argument (velocity)
#
# This is a fresh entry in the operator-interaction map: `@` DISTRIBUTES over `&` (#27,
# @(a&b)≈@a&@b — pointwise), `#` ABSORBS `>` (#64, topic is expansion-invariant), and here
# `>` INTEGRATES over `&` — it does NOT distribute; it finds the connective tissue.
#
# HONEST NOTE — the output is wrapped in literal ( ): that's the cosmetic "paren-echo".
# The grouping paren in `(a & b)` is LOAD-BEARING at parse (it's what makes `>` apply to the
# JOIN rather than just `a` — `>a & b` would parse as `(>a) & b`); the model then echoes the
# delimiter into the text. Harmless, and a fix is prototyped + waiting on a green-light.
#
# Run:  ./examples/golf-aur1-71-weave.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
A='we need better test coverage'; B='we need faster CI'

say "THE WEAVE  >(a & b)  — braids two points into ONE integrated argument (not two separate expansions)"
echo   "  a: $A"
echo   "  b: $B"
echo -n "  >(a & b) => "; "$NLIR" -e ">('$A' & '$B')" --quiet | fold -s -w 80 | sed '2,$s/^/             /'

say "> INTEGRATES over & (finds the through-line) — vs @ distributes (#27), # absorbs > (#64). (Wrapping ( ) = cosmetic paren-echo.)"
