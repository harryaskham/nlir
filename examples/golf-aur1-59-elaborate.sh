#!/usr/bin/env bash
# nlir-golf · aur1 · #59 — "the question elaborator" (a terse worry → a thorough question)
#
# The opposite of my #30 focus-finder. Focus-finder took a rambling wall of worry and
# distilled it DOWN to one crisp question. This runs the other way: `>x?` takes a terse,
# one-line worry and EXPANDS it up into a thorough, well-specified question — `>` fleshes
# out the concern with the context and sub-questions it implies, then `?` frames the whole
# thing as the detailed question you'd actually want answered.
#
#   QUESTION ELABORATOR   > x ?
#     terse "my deploys keep failing"
#     x?  → "Why do my deploys keep failing?"                       ← the bare question
#     >x? → "Why do my deployments keep failing every time I push a release — is this a
#            recurring problem rather than a one-off, where each attempt ends in a failure
#            that stops my changes going live? Is it a specific stage, or…?"  ← the full question
#
# Two directions on the same axis. #30 focus-finder = `ramble?` (a mess IN, one question OUT).
# #59 elaborator = `>x?` (a scrap IN, a rich question OUT). Reach for focus-finder when you
# have too much and need the point; reach for the elaborator when you have too little and
# need the concern spelled out — the vague worry turned into the question worth asking.
#
# Run:  ./examples/golf-aur1-59-elaborate.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
C='my deploys keep failing'

say "QUESTION ELABORATOR  >x?  — a terse worry EXPANDED into a thorough, well-specified question"
echo   "  terse: $C"
echo -n "  x?  (bare question)     => "; "$NLIR" -e "'$C'?"  --quiet | fold -s -w 84 | sed '2,$s/^/       /'
echo -n "  >x? (elaborated question)=> "; "$NLIR" -e ">'$C'?" --quiet | fold -s -w 84 | sed '2,$s/^/       /'

say "The mirror of #30 focus-finder: it distils a ramble to one question; this expands a scrap into a rich one."
