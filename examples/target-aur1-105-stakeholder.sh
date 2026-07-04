#!/usr/bin/env bash
# nlir-TARGET-golf · aur1 · #105 — "the stakeholder question" (Who needs to know about this?)
#
# The "who needs to know about this?" turn — the communication reflex: before acting (or after
# an incident), name who must be informed so nobody's blindsided. A "who needs to know about
# this" seed steers `?` to that notify-the-stakeholders frame.
#
#   TARGET (28 chars):    "Who needs to know about this?"
#   NLIR   (30 src chars): 'who needs to know about this'?
#   REAL OUTPUT:          "Who needs to know about this?"   (exact)
#
#   CLOSENESS: exact. The 94th ? framing. `?` keeps the "who needs to know?" stakeholder-comms
#   frame. Distinct from #54 ownership (whose JOB it is) and #82 routing: this asks who to
#   INFORM / keep in the loop.
#
# Run:  ./examples/target-aur1-105-stakeholder.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "TARGET (28 chars):  Who needs to know about this?"
say "NLIR (30 src chars):  'who needs to know about this'?"
echo -n "  => "; "$NLIR" -e "'who needs to know about this'?" --quiet

say "94th ? framing: 'who needs to know about this' → notify-the-stakeholders / comms (vs #54 ownership, #82 routing)."
