#!/usr/bin/env bash
# nlir-golf · aur1 · #93 — "the open-ended answer" (the full treatment + the question it opens)
#
# Most of my formats END on a decision-question — here's the case, now vote. This one ends
# differently: with the NEXT question. `[>x, >x?]` gives the full answer (`>x`) and then the
# deeper question that answer RAISES (`>x?`, my #59 elaborator) — because a good answer doesn't
# close the topic, it opens a sharper one.
#
#   THE OPEN-ENDED ANSWER   [ >x , >x? ]
#     claim "we should add a caching layer in front of the database"
#     >x  → "We should introduce a caching layer between the app and the database so
#            read-heavy data is served fast without hitting the DB every time…"   ← the ANSWER
#     >x? → "That said, would we need to carefully think through cache INVALIDATION so users
#            aren't served stale data, plus expiration policies and how to handle cache
#            MISSES gracefully?"                                                    ← the QUESTION
#
# See what the second half did: it didn't re-ask the claim, it surfaced the REAL next problem
# — invalidation, expiration, misses — the things you only discover once you've accepted the
# answer. So it's the research-loop shape: answer, then the better question. Distinct from my
# #51 Q&A-card (`[x?, >x]` — question THEN answer) and #67 pre-read (`[~x, >x?]` — gist +
# question): those open with a question; this pairs the FULL answer with the one it provokes.
#
# Run:  ./examples/golf-aur1-93-openended.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
C='we should add a caching layer in front of the database'

say "THE OPEN-ENDED ANSWER  [>x, >x?]  — the full ANSWER (>x) + the deeper QUESTION it raises (>x?)"
echo   "  claim: $C"
echo -n "  >x  (the ANSWER)   => "; "$NLIR" -e ">'$C'"  --quiet | fold -s -w 82 | sed '2,$s/^/       /'
echo -n "  >x? (the QUESTION) => "; "$NLIR" -e ">'$C'?" --quiet | fold -s -w 82 | sed '2,$s/^/       /'

say "The research-loop shape: answer, then the better question. >x? surfaces the NEXT problem (invalidation/misses), not a re-ask. vs #51 Q&A / #67 pre-read (which open WITH a question)."
