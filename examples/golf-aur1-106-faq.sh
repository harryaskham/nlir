#!/usr/bin/env bash
# nlir-golf · aur1 · #106 — "the FAQ entry" (the question + a concise answer, [x?, ~(>x)])
#
# A proper FAQ line: the question, and an answer that's COMPLETE but tight — not an essay.
# `[x?, ~(>x)]` builds both. `x?` poses the question; `~(>x)` (my #22 telephone: expand `>` to draw
# out the substance, then distil `~` to compress it back) yields a single dense sentence that
# still covers the real points. The `>` makes sure nothing important is missing; the `~` makes
# sure it stays FAQ-length.
#
#   THE FAQ ENTRY   [ x? , ~(>x) ]
#     x = "we should use feature flags for all new releases"
#     x?  → "Should we use feature flags for all new releases?"              ← the QUESTION
#     ~(>x) → "Yes — feature flags decouple deployment from release, enabling gradual rollouts,
#            quick disabling of problematic features, and safer delivery."   ← the CONCISE answer
#
# The trick is `~(>x)` hits the sweet spot between too-terse and too-long. Compare my #51 Q&A card
# (`[x?, >x]`): there the answer is bare `>x` — the FULL treatment, several sentences of detail.
# Here `~(>…)` wraps that expansion in a compress, so you get everything that matters in ONE line —
# exactly what belongs under a FAQ heading. (It's the #104 non-commutativity in action: `~(>x)`
# ends on `~`, so it's short.) Question up top, one-line answer under it, next question.
#
# Run:  ./examples/golf-aur1-106-faq.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
C='we should use feature flags for all new releases'

say "THE FAQ ENTRY  [x?, ~(>x)]  — the QUESTION (x?) + a CONCISE, complete answer (~(>x))"
echo   "  x: $C"
echo -n "  x?  (the QUESTION)       => "; "$NLIR" -e "'$C'?"  --quiet | fold -s -w 80 | sed '2,$s/^/       /'
echo -n "  ~(>x) (the CONCISE answer) => "; "$NLIR" -e "~(>'$C')" --quiet | fold -s -w 80 | sed '2,$s/^/       /'

say "~(>x) hits the sweet spot: > draws out the substance, ~ compresses it back to ONE FAQ-length line. vs #51 Q&A [x?, >x] where the answer is the FULL multi-sentence treatment. (#104: ~(>x) ends on ~ → short.)"
