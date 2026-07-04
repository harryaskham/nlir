#!/usr/bin/env bash
# nlir-TARGET-golf · aur1 · #86 — "the automation question" (Should I automate this?)
#
# The "should I automate this?" turn — weighing whether a manual task is worth automating, a
# build-vs-do-by-hand call. A "should i automate this" seed steers `?` to that automation
# decision frame.
#
#   TARGET (24 chars):    "Should I automate this?"
#   NLIR   (26 src chars): 'should i automate this'?
#   REAL OUTPUT (pronoun floats): "Should you automate this?"
#
#   CLOSENESS: exact frame; "I"/"you" floats. The 75th ? framing. `?` keeps the "should I
#   automate this?" build-decision. Distinct from #08 should-I (a generic advisability) and
#   #27 worth-it (net value): this is the specific automate-vs-do-manually call.
#
# Run:  ./examples/target-aur1-86-automation.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "TARGET (24 chars):  Should I automate this?"
say "NLIR (26 src chars):  'should i automate this'?"
echo -n "  => "; "$NLIR" -e "'should i automate this'?" --quiet

say "75th ? framing: 'should i automate this' → the automate-vs-manual call (vs #08 should-I, #27 worth-it)."
