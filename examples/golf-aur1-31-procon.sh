#!/usr/bin/env bash
# nlir-golf · aur1 · #31 — "the pro/con" (a fair debate from one seed)
#
# One claim in, both sides out. `[>x, >!x]` expands a claim into its strongest
# case FOR and, in parallel, expands the NEGATION of the claim into its strongest
# case AGAINST. Symmetric, equal-weight — a fair debate card, not a nudge.
#
#   PRO/CON   [ >x , >!x ]
#     >x   = expand the claim            → the case FOR (why to do it)
#     >!x  = expand the claim's negation → the case AGAINST (why not)
#
#   Seed "ship fast and iterate":
#     >x  → "…get a working version out as quickly as possible rather than
#            delaying for upfront perfection…"                     (the case for)
#     >!x → "Don't rush it out assuming flaws can be patched later… works for
#            cheap-to-reverse decisions, but…"                     (the case against)
#
# Note >!x even self-nuances ("works for reversible decisions, but…"). Distinct
# from #08 steelman/strawman (ASYMMETRIC — one side inflated, one deflated) and
# #13 tempered (which SYNTHESISES one balanced take): here both sides get equal,
# honest expansion and YOU judge. Thesis and antithesis, fully argued, from four
# words. (I tried the full triad [x,!x,~(x&!x)] first — the synthesis slot just
# reports "this contradicts itself"; bare negation doesn't sublate. Pro/con is the
# honest, useful shape.)
#
# Run:  ./examples/golf-aur1-31-procon.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
C='ship fast and iterate'

say "PRO/CON  [>x, >!x]  — expand a claim into the case FOR and the case AGAINST (symmetric debate)"
echo   "  claim: $C"
echo -n "  >x  (case FOR)     => "; "$NLIR" -e ">'$C'" --quiet | fold -s -w 88 | sed '2,$s/^/       /'
echo -n "  >!x (case AGAINST) => "; "$NLIR" -e ">!'$C'" --quiet | fold -s -w 88 | sed '2,$s/^/       /'

say "Thesis and antithesis, equally argued, from 4 words — you judge. (vs #13 which synthesises one take.)"
