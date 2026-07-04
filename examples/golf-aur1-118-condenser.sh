#!/usr/bin/env bash
# nlir-golf · aur1 · #118 — "the condenser" (<[list] folds a bullet list into one fact-dense line)
#
# Point `<` at a LIST and it doesn't pick one item — it FOLDS the whole list into a single tight
# line that keeps every FACT and sheds only the words. That makes `<` a reductive list-operator,
# like `#` and `~`, and unlike `>` (which, being generative, expands only the LAST item, my #77).
#
#   THE CONDENSER   < [ fact1 , fact2 , fact3 ]
#     < [ 'error rate spiked right after the deploy' ,
#         'the on-call engineer got paged at 3am' ,
#         'we rolled back within 20 minutes and it recovered' ]
#       → "Error rate spiked right after deploy; on-call was paged at 3am. Rolled back within
#          20 minutes and it recovered."                                     ← ALL three, one line
#     > [ same three ] → "…the team opted to roll back the release rather than attempt a live
#          fix under time pressure…"                                         ← only the LAST, expanded
#
# So the reduce-vs-produce split of #89 has a clean third member: REDUCTIVE ops (`#` → the
# subject, `~` → the gist, `<` → the fact-dense condensation) all FOLD a whole list into one
# result; the GENERATIVE op (`>`) takes only the last and blooms it. The practical win: `<[…]`
# collapses a bullet list, an incident timeline, a set of findings into ONE line you can paste
# into a status — every fact preserved (that's `<`'s info-floor, #35), just the padding gone.
# Where `~[list]` gives the CONSENSUS/theme (#07, sheds detail), `<[list]` keeps the DETAIL and
# only tightens the prose. Condense, don't summarise.
#
# Run:  ./examples/golf-aur1-118-condenser.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
L="['our error rate spiked right after the deploy went out','the on-call engineer got paged at 3am','we rolled back within twenty minutes and it recovered']"

say "THE CONDENSER  <[list]  — FOLDS a list of facts into ONE fact-dense line (all facts kept, words shed)"
echo -n "  <[3 incident facts] => "; "$NLIR" -e "<$L" --quiet | fold -s -w 80 | sed '2,$s/^/       /'
echo -n "  >[same 3] (#77, LAST only) => "; "$NLIR" -e ">$L" --quiet | fold -s -w 80 | sed '2,$s/^/       /'

say "< is REDUCTIVE on a list (FOLDS, like #/~), > is GENERATIVE (takes the LAST, #77). The reduce-vs-produce split of #89, third member. <[list] keeps DETAIL (info-floor #35) vs ~[list] keeps the THEME (#07). Condense, don't summarise."
