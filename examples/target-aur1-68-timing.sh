#!/usr/bin/env bash
# nlir-TARGET-golf · aur1 · #68 — "the timing question" (Is now a good time to X?)
#
# The "is now a good time to X?" turn — asking whether the MOMENT is right to act, a
# readiness/timing check on the present. A "is now a good time to X" seed steers `?` to
# the "Is now a good time to X?" timing frame.
#
#   TARGET (32 chars):    "Is now a good time to refactor?"
#   NLIR   (33 src chars): 'is now a good time to refactor'?
#   REAL OUTPUT:          "Is now a good time to refactor?"   (exact)
#
#   CLOSENESS: exact. The 57th ? framing. `?` keeps the "is now a good time to …?" timing
#   frame. Distinct from #61 lateness (has the window CLOSED) and #11 when (schedule a
#   time): this asks whether the PRESENT moment is opportune — go now, or wait?
#
# Run:  ./examples/target-aur1-68-timing.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "TARGET (32 chars):  Is now a good time to refactor?"
say "NLIR (33 src chars):  'is now a good time to refactor'?"
echo -n "  => "; "$NLIR" -e "'is now a good time to refactor'?" --quiet

say "57th ? framing: 'is now a good time to X' → is the PRESENT moment opportune (vs #61 too-late, #11 when-schedule)."
