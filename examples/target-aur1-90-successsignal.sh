#!/usr/bin/env bash
# nlir-TARGET-golf · aur1 · #90 — "the success-signal question" (How will I know if this is working?)
#
# The "how will I know if this is working?" turn — asking for the observable SIGNAL that tells
# you a change is succeeding, a define-your-metric ask. A first-person "how will i know if this
# is working" seed steers `?` to that success-criterion frame.
#
#   TARGET (32 chars):    "How will I know if this is working?"
#   NLIR   (34 src chars): 'how will i know if this is working'?
#   REAL OUTPUT (pronoun floats): "How will you know if this is working?"
#
#   CLOSENESS: exact frame; "I"/"you" floats. The 79th ? framing. `?` keeps the "how will I
#   know if …?" success-signal frame. Distinct from #74 does-this-scale (a property) and #80
#   testing (verify correctness): this asks for the METRIC that proves it's succeeding.
#
# Run:  ./examples/target-aur1-90-successsignal.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "TARGET (32 chars):  How will I know if this is working?"
say "NLIR (34 src chars):  'how will i know if this is working'?"
echo -n "  => "; "$NLIR" -e "'how will i know if this is working'?" --quiet

say "79th ? framing: 'how will i know if this is working' → the success SIGNAL/metric (vs #74 does-this-scale, #80 testing)."
