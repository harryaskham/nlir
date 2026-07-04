#!/usr/bin/env bash
# nlir-TARGET-golf · aur1 · #70 — "the stopping-criterion question" (How do I know when to stop X?)
#
# The "how do I know when to stop X?" turn — asking for the SIGNAL that says you're done,
# a completion-criterion check. A "how do i know when to stop X" seed steers `?` to the
# "How do I know when to stop X?" enough-signal frame.
#
#   TARGET (~40 chars):   "How do I know when to stop optimizing?"
#   NLIR   (40 src chars): 'how do i know when to stop optimizing'?
#   REAL OUTPUT (pronoun floats): "How do you know when to stop optimizing?"
#
#   CLOSENESS: exact frame; "do I"/"do you" floats. The 59th ? framing: "how do i know when
#   to stop X" asks for the SIGNAL that it's enough — distinct from #51 cessation (how to
#   stop) and #47 trigger (when to START): the criterion that says you're done.
#
# Run:  ./examples/target-aur1-70-stopping.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "TARGET (~40 chars):  How do I know when to stop optimizing?"
say "NLIR (40 src chars):  'how do i know when to stop optimizing'?"
echo -n "  => "; "$NLIR" -e "'how do i know when to stop optimizing'?" --quiet

say "59th ? framing: 'how do i know when to stop X' → the SIGNAL you're done (vs #51 cessation, #47 trigger)."
