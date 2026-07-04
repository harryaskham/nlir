#!/usr/bin/env bash
# nlir-TARGET-golf · aur1 · #82 — "the routing question" (Who do I ask about X?)
#
# The "who do I ask about X?" turn — finding the right PERSON/owner to go to, an expertise-
# routing question. A "who do i ask about X" seed steers `?` to the "Who do I ask about X?"
# go-to-person frame.
#
#   TARGET (~35 chars):   "Who do I ask about the billing system?"
#   NLIR   (38 src chars): 'who do i ask about the billing system'?
#   REAL OUTPUT (pronoun floats): "Who do you ask about the billing system?"
#
#   CLOSENESS: exact frame; "do I"/"do you" floats. The 71st ? framing: "who do I ask about
#   X" routes to a PERSON — distinct from #13 who (who did/is it) and #54 ownership (who
#   SHOULD own it): this finds who to GO TO for help on X.
#
# Run:  ./examples/target-aur1-82-routing.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "TARGET (~35 chars):  Who do I ask about the billing system?"
say "NLIR (38 src chars):  'who do i ask about the billing system'?"
echo -n "  => "; "$NLIR" -e "'who do i ask about the billing system'?" --quiet

say "71st ? framing: 'who do i ask about X' → route to the go-to PERSON (vs #13 who-did-it, #54 who-should-own)."
