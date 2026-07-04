#!/usr/bin/env bash
# nlir-golf · aur1 · #101 — "the steelman duel" (both sides, full and raw, equal strength: [>x, >!x])
#
# A fair fight. `[>x, >!x]` builds BOTH sides of a claim as full arguments at equal strength:
# `>x` expands the case FOR, `>!x` (my #99 skeptic — negate then expand) builds the case
# AGAINST. Both are raw arguments in the same register — no thumb on the scale.
#
#   THE STEELMAN DUEL   [ >x , >!x ]
#     x = "we should require code review on every single change"
#     >x  → "Yes — reviewing everything catches bugs early, spreads knowledge, keeps a
#            consistent bar, and the friction is worth the long-term quality…"   ← case FOR
#     >!x → "No — mandatory review on every trivial change adds latency, bottlenecks on
#            reviewers, and burns goodwill on one-line fixes; risk-tier it instead…"  ← case AGAINST
#
# The point is the SYMMETRY. My #31 pro-con runs `[>x, >@!x]` — the `@` makes the counter a
# measured, formal COUNTER-PROPOSAL (the diplomat), so the two halves aren't the same weight
# class. Here both halves are bare `>` expansions — two heavyweights, same register, equal
# swing. And unlike my #97 disarm (objection-first, to defuse), the duel isn't trying to win;
# it lays both cases out at full strength and lets the reader score the round. The honest way
# to look at something you're genuinely torn on.
#
# Run:  ./examples/golf-aur1-101-steelmanduel.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
C='we should require code review on every single change'

say "THE STEELMAN DUEL  [>x, >!x]  — both sides as full RAW arguments, same register, equal strength"
echo   "  x: $C"
echo -n "  >x  (the case FOR)     => "; "$NLIR" -e ">'$C'"  --quiet | fold -s -w 80 | sed '2,$s/^/       /'
echo -n "  >!x (the case AGAINST) => "; "$NLIR" -e ">!'$C'" --quiet | fold -s -w 80 | sed '2,$s/^/       /'

say "SYMMETRY is the point: both halves are bare > expansions (same weight class), vs #31 pro-con [>x,>@!x] where @ makes the counter a formal proposal. And vs #97 disarm (objection-first to win), the duel just lays both out — the reader scores it."
