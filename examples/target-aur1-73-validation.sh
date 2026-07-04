#!/usr/bin/env bash
# nlir-TARGET-golf · aur1 · #73 — "the validation question" (Am I on the right track?)
#
# The "am I on the right track?" turn — a mid-effort check for reassurance that your
# direction is sound, not a fault-find or a restart. A first-person "am i on the right
# track" seed steers `?` to the "Am I on the right track?" direction-check frame.
#
#   TARGET (24 chars):    "Am I on the right track?"
#   NLIR   (26 src chars): 'am i on the right track'?
#   REAL OUTPUT:          "Am I on the right track?"   (exact)
#
#   CLOSENESS: exact. The 62nd ? framing. `?` keeps the "on the right track?" validation
#   frame. Distinct from #66 sanity (am I overthinking) and #53 good-idea (is the plan
#   sound): this asks whether your current DIRECTION/approach is heading the right way.
#
# Run:  ./examples/target-aur1-73-validation.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "TARGET (24 chars):  Am I on the right track?"
say "NLIR (26 src chars):  'am i on the right track'?"
echo -n "  => "; "$NLIR" -e "'am i on the right track'?" --quiet

say "62nd ? framing: 'am i on the right track' → validate your DIRECTION (vs #66 overthinking, #53 good-idea)."
