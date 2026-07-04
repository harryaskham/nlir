#!/usr/bin/env bash
# nlir-golf · aur1 · #102 — "the discussion header" (the topic + the decision, [#x, x?])
#
# The line you pin to the top of a thread. `[#x, x?]` states, in two moves, WHAT we're talking
# about and WHAT we're deciding: `#x` collapses the claim to its SUBJECT (a bare topic label),
# and `x?` turns the same claim into the yes/no on the table.
#
#   THE DISCUSSION HEADER   [ #x , x? ]
#     x = "we should adopt kubernetes for our container orchestration"
#     #x → "Kubernetes for container orchestration"               ← the TOPIC (subject label)
#     x? → "Should we adopt Kubernetes for our container orchestration?"   ← the DECISION
#
# It's the leanest possible opener: no claim stated, no case made — just the subject as a
# header and the question underneath, ready for a thread or an agenda line. Compare my #61
# decision-opener (`[@x, x?]`): that leads with the FULL formal claim ("We should adopt…"); this
# leads with just the two-word SUBJECT, so it reads like a heading, not a position. `#` is doing
# what it does best here — folding a whole sentence down to what it's ABOUT (my #64: `#` ignores
# the verb and the stance, keeps the noun).
#
# Run:  ./examples/golf-aur1-102-header.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
C='we should adopt kubernetes for our container orchestration'

say "THE DISCUSSION HEADER  [#x, x?]  — the TOPIC (#x, the subject label) + the DECISION (x?)"
echo   "  x: $C"
echo -n "  #x (the TOPIC)    => "; "$NLIR" -e "#'$C'" --quiet | fold -s -w 80 | sed '2,$s/^/       /'
echo -n "  x? (the DECISION) => "; "$NLIR" -e "'$C'?" --quiet | fold -s -w 80 | sed '2,$s/^/       /'

say "The leanest opener: subject as a heading + the question underneath. vs #61 decision-opener [@x,x?] (leads with the FULL formal claim); this leads with just the two-word SUBJECT — a heading, not a position. # folds the sentence to what it's ABOUT (#64)."
