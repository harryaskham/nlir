#!/usr/bin/env bash
# nlir-golf · aur1 · #72 — "what the question keeps" (? absorbs ~ :  ~x? ≈ x?, but >x? differs)
#
# A capstone for the `?` projection. Over many examples `?` has swallowed prior operators:
# it absorbs `!` (#36, `!x?≈x?`), it absorbs `@` (#37, register doesn't survive a question).
# Here it absorbs `~` too — asking about a claim and asking about its GIST give the same
# question, because the summary threw away nothing the question was going to keep anyway:
#
#     ~x?  ≈  x?          but      >x?  ≠  x?
#
#   claim "our onboarding has a 40% drop-off at the email verification step, mostly on mobile"
#     x?  → "Does our onboarding have a 40% drop-off at email verification, mostly on mobile?"
#     ~x? → "Does onboarding see a 40% drop-off at email verification, mainly on mobile?"   ← same Q
#     >x? → "Is our onboarding losing a substantial share of new users specifically at the
#            email-verification stage, where ~40% of people who reach it…"                 ← richer Q
#
# So the whole family resolves into one law: `?` is a projection onto INFORMATION content.
# It absorbs every prior op that does NOT add information — negation (`!`), register (`@`),
# compression (`~`) — because none of those change what the question can hold. The ONLY
# operator that changes `x?` is `>` (#59 elaborator), because expansion ADDS information,
# and the question keeps it. Question the claim, question its gist, question its formal or
# negated form — you land on the same question; only fleshing it out first makes it bigger.
#
# Run:  ./examples/golf-aur1-72-projection.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
C='our onboarding has a forty percent drop-off at the email verification step, mostly on mobile'

say "WHAT THE QUESTION KEEPS  — ? absorbs ~ (~x? ≈ x?), but > adds info the question keeps (>x? ≠ x?)"
echo   "  claim: $C"
echo -n "  x?  (question)          => "; "$NLIR" -e "'$C'?"  --quiet | fold -s -w 80 | sed '2,$s/^/       /'
echo -n "  ~x? (question of gist)  => "; "$NLIR" -e "~'$C'?" --quiet | fold -s -w 80 | sed '2,$s/^/       /'
echo -n "  >x? (question of expand) => "; "$NLIR" -e ">'$C'?" --quiet | fold -s -w 80 | sed '2,$s/^/       /'

say "? projects onto INFORMATION: absorbs !(#36)/@(#37)/~(#72) — anything that doesn't add info — and only >(#59) changes the question."
