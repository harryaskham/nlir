#!/usr/bin/env bash
# nlir-golf · aur1 · #95 — "the question ladder" (the same question at two altitudes, [x?, >x?])
#
# Yesterday's skim-or-study (#94) laddered the ANSWER — gist on top, deep-dive below. This is
# its mirror on the QUESTION side. `[x?, >x?]` poses one question at two altitudes: `x?` is the
# HEADLINE — the one-line poll everyone can vote on — and `>x?` is the DETAILED — the same
# question fully specified (my #59 elaborator), unrolling the sub-considerations you'd actually
# have to work through. Slack poll up top, RFC prompt underneath.
#
#   THE QUESTION LADDER   [ x? , >x? ]
#     x = "we should adopt a monorepo for all our services"
#     x?  → "Should we adopt a monorepo for all our services?"                    ← the HEADLINE
#     >x? → "Should we consolidate all our services into a single monorepo rather than many
#            separate repos — versioning everything together, making atomic cross-service
#            changes, and accepting the tooling/scale tradeoffs?"                 ← the DETAILED
#
# The `>x?` half didn't wander to a NEW question — it deepened the SAME one, surfacing the
# axes a real decision has to weigh (atomic changes, tooling, scale). That's the ladder: one
# question, two resolutions. It differs from my #67 pre-read (`[~x, >x?]` — a gist THEN a
# question); here BOTH rungs are questions — the quick ask and the thorough ask, so a reader
# can vote on the headline or engage with the full prompt.
#
# Run:  ./examples/golf-aur1-95-questionladder.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
C='we should adopt a monorepo for all our services'

say "THE QUESTION LADDER  [x?, >x?]  — the HEADLINE question (x?, poll) + the DETAILED one (>x?, RFC prompt)"
echo   "  x: $C"
echo -n "  x?  (the HEADLINE) => "; "$NLIR" -e "'$C'?"  --quiet | fold -s -w 82 | sed '2,$s/^/       /'
echo -n "  >x? (the DETAILED) => "; "$NLIR" -e ">'$C'?" --quiet | fold -s -w 82 | sed '2,$s/^/       /'

say "One question, two altitudes: >x? DEEPENS the same question (surfaces the axes to weigh), it doesn't ask a new one. The question-side mirror of #94 skim-or-study. vs #67 pre-read [~x,>x?] (gist THEN question)."
