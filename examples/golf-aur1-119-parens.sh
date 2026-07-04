#!/usr/bin/env bash
# nlir-golf · aur1 · #119 — "parens are load-bearing" (!(a&b) ≠ !a&b : grouping sets an operator's SCOPE)
#
# nlir has TWO kinds of parentheses, and only one is real. The paren-echo I keep flagging is
# COSMETIC — the model sometimes prints a group's brackets in its output (a display bug, fix
# prototyped). But grouping at PARSE is STRUCTURAL and load-bearing: it decides what an operator
# ACTS ON. Same sigils, one pair of parens, opposite meaning:
#
#   PARENS SET SCOPE     a = "the tests pass" , b = "the build works"
#     !( a & b )  → "the tests fail AND the build doesn't work"    ← `!` negates the WHOLE group
#     !a & b      → "the tests don't pass AND the build works"     ← `!` negates ONLY `a`; b stays
#
# Look at `b`: with parens it's negated ("doesn't work"); without, it's untouched ("works"). The
# parens changed the SCOPE of `!` — inside `!(a&b)` the negation covers both operands, but bare
# `!a & b` binds `!` tightly to `a` and then joins an unmodified `b`. This is why grouping is
# structural: `!(a&b)` and `!a&b` are DIFFERENT PROGRAMS with different results, not just
# different formatting.
#
# So the rule of thumb: reach for parens to widen an operator's reach over a whole compound
# (`!(a & b & c)` = falsify all three), and drop them to keep it pinned to the first operand.
# And don't confuse this with the cosmetic paren-echo — that stray "(" in `!(a&b)`'s output is
# purely visual; the grouping that produced it is doing real structural work.
#
# Run:  ./examples/golf-aur1-119-parens.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "PARENS ARE LOAD-BEARING  !(a&b) ≠ !a&b  — grouping sets what \`!\` ACTS ON (its SCOPE)"
echo   "  a: the tests pass   |   b: the build works"
echo -n "  !(a & b)  [negate the WHOLE group] => "; "$NLIR" -e "!('the tests pass' & 'the build works')" --quiet | fold -s -w 80 | sed '2,$s/^/       /'
echo -n "  !a & b    [negate ONLY a; b stays] => "; "$NLIR" -e "!'the tests pass' & 'the build works'"   --quiet | fold -s -w 80 | sed '2,$s/^/       /'

say "Watch b: negated with parens ('doesn't work'), untouched without ('works'). Parens set the SCOPE of ! — !(a&b) and !a&b are DIFFERENT PROGRAMS (structural at PARSE), NOT just formatting. (Distinct from the cosmetic paren-ECHO in the output — that's a display bug; this grouping does real work.)"
