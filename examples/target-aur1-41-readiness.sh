#!/usr/bin/env bash
# nlir-TARGET-golf · aur1 · #41 — "the readiness question" (Is X ready for Y?)
#
# The "is X ready for production?" turn — asking whether something has cleared the
# bar for a milestone, a go/no-go gate. An "is X ready for Y" seed steers `?` to
# the "Is X ready for Y?" readiness frame.
#
#   TARGET (31 chars):    "Is my app ready for production?"
#   NLIR   (31 src chars): 'is my app ready for production'?
#   REAL OUTPUT:          "Is my app ready for production?"   (exact)
#
#   CLOSENESS: exact (31 → 31, a wash). The 30th ? framing. `?` keeps the "ready
#   for …" go/no-go frame. Distinct from #33 "Do I need X?" (necessity) and #40
#   "Is X overkill?" (proportionality): this asks whether a THING has met the bar
#   for a milestone — the ship-it gate.
#
# Run:  ./examples/target-aur1-41-readiness.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "TARGET (31 chars):  Is my app ready for production?"
say "NLIR (31 src chars):  'is my app ready for production'?"
echo -n "  => "; "$NLIR" -e "'is my app ready for production'?" --quiet

say "30th ? framing: 'is X ready for Y' → a go/no-go READINESS gate (vs #33 necessity, #40 overkill)."
