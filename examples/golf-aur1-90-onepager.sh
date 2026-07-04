#!/usr/bin/env bash
# nlir-golf · aur1 · #90 — "the one-pager" (one claim → a complete one-page document) · MILESTONE
#
# Ninetieth example. At #70 I built the decision packet — recommendation, both cases, the
# question. This is the document it grows into: a formatted ONE-PAGER, generated whole from a
# single sentence. Five sections, five sigils, top to bottom you could paste it into a wiki.
#
#   THE ONE-PAGER   [ #x , @~x , >x , >@!x , x? ]
#     claim "we should migrate our monolith to microservices"
#     #x   → "Migrating a monolith to microservices"                         ← TITLE
#     @~x  → "The team intends to transition its monolithic architecture to a
#             microservices-based architecture."                             ← ABSTRACT
#     >x   → "We should migrate… our monolith bundles all functionality into one deployable,
#             which slows teams and couples releases…"                       ← THE CASE
#     >@!x → "Beyond the added complexity, the migration would be costly and risky, consuming
#             engineering effort with no guaranteed payoff…"                 ← THE COUNTER-CASE
#     x?   → "Should we migrate our monolith to microservices?"              ← THE QUESTION
#
# Each sigil owns a section: `#` titles (the topic as a heading), `@~` abstracts (formal +
# brief), `>` argues for, `>@!` argues against (my opposition brief), `?` frames the decision.
# Read top to bottom it's a real reviewer's one-pager — heading, abstract, both sides in full,
# and the exact question — all unfolded from seven words. It's the DOCUMENT capstone of the
# analytical wheel (#60, one claim on every axis) and the decision packet (#70, the memo):
# where the wheel refracts and the packet decides, the one-pager PUBLISHES.
#
# Run:  ./examples/golf-aur1-90-onepager.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
w() { for i in 1 2 3; do R=$("$NLIR" -e "$1" --quiet 2>/dev/null | tail -1); [ -n "$R" ] && { printf '%s' "$R"; return; }; sleep 3; done; }
C='we should migrate our monolith to microservices'

say "THE ONE-PAGER  [#x, @~x, >x, >@!x, x?]  — TITLE / ABSTRACT / THE CASE / THE COUNTER-CASE / THE QUESTION"
echo   "  claim: $C"
echo -n "  #x   TITLE       => "; w "#'$C'";  echo
echo -n "  @~x  ABSTRACT    => "; w "@~'$C'" | fold -s -w 78 | sed '2,$s/^/                   /'; echo
echo -n "  >x   THE CASE    => "; w ">'$C'"  | fold -s -w 78 | sed '2,$s/^/                   /'; echo
echo -n "  >@!x COUNTER-CASE=> "; w ">@!'$C'" | fold -s -w 78 | sed '2,$s/^/                   /'; echo
echo -n "  x?   THE QUESTION=> "; w "'$C'?"; echo

say "Each sigil owns a section: # titles, @~ abstracts, > argues for, >@! argues against, ? decides. A whole one-pager from 7 words. (wheel #60 refracts, packet #70 decides, this PUBLISHES.)"
