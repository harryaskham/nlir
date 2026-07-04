#!/usr/bin/env bash
# nlir-golf · aur1 · #98 — "the terse memo" (the shortest FORMAL statement, <@x ≈ @<x)
#
# Turn a rambling Slack vent into the one-line official statement — and prove an algebra law
# doing it. `<@x` shortens the formalised version; `@<x` formalises the shortened version. Both
# land in the same place: a single formal sentence. That's because REGISTER (`@`) and LENGTH
# (`<`) are orthogonal axes — neither operator changes what the other one touches — so they
# COMMUTE (my #75 commutativity rule).
#
#   THE TERSE MEMO   <@x  ≈  @<x        (formal register × minimum length)
#     x = "hey so basically the thing is our deploys keep breaking because nobody actually runs
#          the tests before pushing and honestly its getting kind of out of hand"
#     <@x → "Deployments frequently fail because tests aren't run before pushing code—this
#            needs attention."                                        (shorten the formal)
#     @<x → "Deployments continue to fail because tests are not executed prior to pushing
#            changes."                                                (formalise the short)
#
# Same content, same register, same length — the two orderings converge. This EXTENDS #75
# (`@>x ≈ >@x`, register commutes with EXPAND) to the other length direction: register commutes
# with SHORTEN too, so register ⊥ BOTH ways along the length axis. The payoff is practical: a
# heated one-liner you can paste into an incident channel or a status doc, distilled from a
# paragraph of noise. (Contrast #48 polish `>@x` — register × EXPAND, the long formal write-up;
# this is register × SHORTEN, the short formal note.)
#
# Run:  ./examples/golf-aur1-98-tersememo.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
C='hey so basically the thing is our deploys keep breaking because nobody actually runs the tests before pushing and honestly its getting kind of out of hand'

say "THE TERSE MEMO  <@x ≈ @<x  — the shortest FORMAL statement (register × minimum length, and they COMMUTE)"
echo   "  x: $C"
echo -n "  <@x (shorten the formal)  => "; "$NLIR" -e "<@'$C'" --quiet | fold -s -w 80 | sed '2,$s/^/       /'
echo -n "  @<x (formalise the short) => "; "$NLIR" -e "@<'$C'" --quiet | fold -s -w 80 | sed '2,$s/^/       /'

say "Both orderings converge → @ commutes with < (register ⊥ SHORTEN), extending #75 (@>≈>@, register ⊥ EXPAND). A paragraph of noise → a one-line official statement. (cf #48 polish >@x = register × EXPAND.)"
