#!/usr/bin/env bash
# nlir-golf · aur1 · #37 — "the question factors through content" (which axes ? strips)
#
# #36 showed ? absorbs polarity (!x? ≈ x?). So which axes does it absorb, and which
# does it respect? The answer draws a clean STYLE-vs-SUBSTANCE boundary. `?` strips
# the pure-STYLE axes — register and polarity — because how you DRESS a claim
# doesn't change what's being asked. But it RESPECTS information: expand ADDS
# content, so the question grows to cover it.
#
#   FACTORS THROUGH CONTENT
#     x?   →  "Should we migrate the database this weekend?"
#     @x?  →  "Should we migrate the database this weekend?"   (register STRIPPED ✓)
#     !x?  →  "Should we migrate the database this weekend?"   (polarity STRIPPED ✓ #36)
#     >x?  →  "Shouldn't we migrate…given the low-traffic window…wouldn't off-hours
#              give a rollback buffer…and time for backups and on-call…?"
#              (expand ADDED reasons → a long multi-clause question — RESPECTED ✗)
#
# So ? is INVARIANT to style (@ register, ! polarity) but SENSITIVE to substance
# (> information). It mirrors msm0's ~: both factor through CONTENT, ignoring how
# the claim is dressed. Practically: formalise/negate all you like before a ? and
# you get the same question; but if you EXPAND first, you're asking a bigger one.
#
# Run:  ./examples/golf-aur1-37-factor.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
C='we should migrate the database this weekend'

say "? FACTORS THROUGH CONTENT — strips STYLE (@ register, ! polarity), respects SUBSTANCE (> info)"
echo -n "  x?   (bare)     => "; "$NLIR" -e "'$C'?"  --quiet
echo -n "  @x?  (formal)   => "; "$NLIR" -e "@'$C'?" --quiet
echo -n "  !x?  (negated)  => "; "$NLIR" -e "!'$C'?" --quiet
echo -n "  >x?  (expanded) => "; "$NLIR" -e ">'$C'?" --quiet | fold -s -w 84 | sed '2,$s/^/       /'

say "@x? ≈ !x? ≈ x? (style stripped); >x? differs (info added). ? is invariant to style, sensitive to substance."
