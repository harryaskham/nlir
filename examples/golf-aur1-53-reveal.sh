#!/usr/bin/env bash
# nlir-golf · aur1 · #53 — "the reveal" (build the context, then land the takeaway)
#
# The narrative order — and the deliberate REVERSE of my #44 BLUF. `[>x, ~x]` expands
# the fact into its full context FIRST, walking the reader through the situation, and
# only THEN drops the one-line takeaway as the closing punch. Where BLUF leads with the
# answer for a skimmer, the reveal WITHHOLDS it — building understanding before the
# verdict, the way a postmortem or a story wants to be read.
#
#   THE REVEAL   [ >x , ~x ]
#     fact "the outage was caused by a config typo that set the pool to 5 instead of 50"
#     >x  → "The outage was ultimately traced to a simple but costly configuration error:
#            a typo in the settings file set the maximum connection-pool size to 5 instead
#            of the intended 50, so under load the app ran out of connections…"   ← the build-up
#     ~x  → "The outage was caused by a typo that misconfigured the connection pool size
#            (5 instead of 50)."                                                    ← the landing
#
# Same two ops as BLUF, reversed. BLUF `[~x, >x]` = takeaway-then-support, for the reader
# who might stop after line one. The reveal `[>x, ~x]` = context-then-takeaway, for the
# reader you want to walk through it before the conclusion lands. The ORDER is the whole
# design choice: efficiency vs narrative.
#
# Run:  ./examples/golf-aur1-53-reveal.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
C='the outage was caused by a config typo that set the connection pool to 5 instead of 50'

say "THE REVEAL  [>x, ~x]  — build the full context (>x), THEN land the one-line takeaway (~x)"
echo   "  fact: $C"
echo    "  >x (the build-up) =>"; "$NLIR" -e ">'$C'" --quiet | fold -s -w 86 | sed 's/^/     /'
echo -n "  ~x (the landing)  => "; "$NLIR" -e "~'$C'" --quiet | fold -s -w 86 | sed '2,$s/^/       /'

say "Same two ops as #44 BLUF, REVERSED: BLUF = answer-then-support (efficiency); reveal = context-then-answer (narrative)."
