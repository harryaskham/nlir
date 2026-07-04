#!/usr/bin/env bash
# nlir-golf · aur1 · #111 — "register commutes with polarity (and why > was the exception)" (@!x ≈ !@x)
#
# My #87 found a puzzle: expand and negate DON'T commute (`>!x ≠ !>x`) even though length and
# polarity are orthogonal axes. This card resolves it. The refined rule from #87 was: orthogonal
# operators commute ONLY when neither changes WHAT the other operates on. Here's the clean case
# that proves the rule — and shows exactly why `>` was the lone exception.
#
#   REGISTER ⊥ POLARITY — THEY COMMUTE     x = "the new onboarding flow is a huge success"
#     @!x (formalise the negation) → "The revised onboarding flow has yielded limited success."
#     !@x (negate the formal)      → "The new onboarding flow has proven to be unsuccessful."
#         → both land in the SAME place: formal register + negative polarity. Order doesn't matter.
#
#   LENGTH ⊥ POLARITY — THEY DON'T (my #87)
#     >!x (expand the negation) → "…has not turned out to be the significant improvement hoped…"
#     !>x (negate the expansion)→ "…has turned out to be an utter failure, falling short across…"
#         → these DIVERGE: measured doubt vs total failure. Order changes the framing.
#
# The difference: `@` is a PURE register move — it re-voices the claim but leaves it a claim, so
# `!` negates the same thing either way (→ commute). `>` is a TYPE-CHANGING move — it turns the
# claim into an ARGUMENT, and negating a claim ("not a success") is a different act from negating
# an argument ("flip every clause" → "utter failure"), so order matters (→ don't commute). So the
# commutativity map is complete: register⊥length (#75/#98) and register⊥polarity (here) COMMUTE
# because `@` never changes an operand's type; the ONLY orthogonal pair that fails is the one
# involving `>` (#87), precisely because `>` does. Rule of thumb: reorder freely around `@`;
# never reorder `!` across `>`.
#
# Run:  ./examples/golf-aur1-111-registerpolarity.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
C='the new onboarding flow is a huge success'

say "REGISTER ⊥ POLARITY COMMUTE  @!x ≈ !@x  (both = formal + negative), vs LENGTH⊥POLARITY #87 (>!x ≠ !>x)"
echo   "  x: $C"
echo -n "  @!x (formalise the NEG) => "; "$NLIR" -e "@!'$C'" --quiet | fold -s -w 80 | sed '2,$s/^/       /'
echo -n "  !@x (negate the FORMAL) => "; "$NLIR" -e "!@'$C'" --quiet | fold -s -w 80 | sed '2,$s/^/       /'
echo   "  --- contrast (#87): > is type-changing, so it does NOT commute with ! ---"
echo -n "  >!x (expand the NEG)    => "; "$NLIR" -e ">!'$C'" --quiet | fold -s -w 80 | sed '2,$s/^/       /'
echo -n "  !>x (negate the EXPAND) => "; "$NLIR" -e "!>'$C'" --quiet | fold -s -w 80 | sed '2,$s/^/       /'

say "@ is a PURE register move (claim stays a claim) → @!≈!@ commute. > is TYPE-CHANGING (claim→argument) → >!≠!>x diverge (#87). Reorder freely around @; never reorder ! across >."
