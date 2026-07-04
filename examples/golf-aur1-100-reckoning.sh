#!/usr/bin/env bash
# nlir-golf · aur1 · #100 🎯 CAPSTONE — "the full reckoning" ([@~x, >x, >!x, x?])
#
# One hundred. To crown the century: the decision-maker's complete workup — a single claim run
# through four lenses that argue it honestly and then hand you the call. Every section is owned
# by its own sigil-phrase, and together they weave in the moves this whole run has been about.
#
#   THE FULL RECKONING   [ @~x , >x , >!x , x? ]
#     @~x  the ABSTRACT   — formalise the gist: the proposal in one clean line   (my #91 exec-brief)
#     >x   the CASE       — the full argument FOR                                (my #77)
#     >!x  the SKEPTIC    — negate, then expand: the full argument it's WRONG    (my #99, newest)
#     x?   the DECISION   — the same idea as the yes/no on the table
#
#   x = "we should sunset the legacy api and move everyone to v2"
#     @~x → "The legacy API will be deprecated and all users migrated to v2."
#     >x  → "We should retire the legacy API and transition every user, integration and
#            dependency to v2, because a single supported surface cuts maintenance and risk…"
#     >!x → "We should NOT sunset the legacy API while forcing migration — breaking existing
#            integrations, stranding users who can't move in time, and risking churn…"
#     x?  → "Should we sunset the legacy API and move everyone to v2?"
#
# Where the #90 one-pager PUBLISHES (title, abstract, both sides, question — a document), the
# reckoning DECIDES: it swaps the polite counter-brief for the raw SKEPTIC (#99), so you face
# the strongest disconfirming case at full strength before you commit. Read top to bottom:
# what's proposed → why → why it might be a mistake → now choose. It's the honest way to make a
# call — and a fitting close to 100 concepts spent turning tiny stacks of sigils into thought.
#
# Milestones on the road here: #50 deliberation · #60 the perspective wheel · #70 decision packet
# · #80 conversation dashboard · #90 the one-pager · #100 the full reckoning.
#
# Run:  ./examples/golf-aur1-100-reckoning.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
C='we should sunset the legacy api and move everyone to v2'

say "🎯 #100 THE FULL RECKONING  [@~x, >x, >!x, x?]  — ABSTRACT / THE CASE / THE SKEPTIC / THE DECISION"
echo "  claim: $C"
echo -n "  @~x  (ABSTRACT) => "; "$NLIR" -e "@~'$C'" --quiet | fold -s -w 80 | sed '2,$s/^/                    /'
echo -n "  >x   (THE CASE) => "; "$NLIR" -e ">'$C'"  --quiet | fold -s -w 80 | sed '2,$s/^/                    /'
echo -n "  >!x  (SKEPTIC)  => "; "$NLIR" -e ">!'$C'" --quiet | fold -s -w 80 | sed '2,$s/^/                    /'
echo -n "  x?   (DECISION) => "; "$NLIR" -e "'$C'?"  --quiet | fold -s -w 80 | sed '2,$s/^/                    /'

say "The decision sibling of #90 one-pager: swaps the polite counter-brief for the raw SKEPTIC (#99) — face the strongest disconfirming case at full strength, then choose. 100 concepts of turning tiny sigil-stacks into thought. 🏁"
