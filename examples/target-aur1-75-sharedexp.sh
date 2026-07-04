#!/usr/bin/env bash
# nlir-TARGET-golf · aur1 · #75 — "the shared-experience question" (Is it just me, or is this X?)
#
# The "is it just me, or is this confusing?" turn — checking whether a reaction is yours
# alone or widely shared, a social sanity check. A "is it just me or is this confusing" seed
# steers `?` to the "Is it just me, or is this confusing?" shared-experience frame.
#
#   TARGET (33 chars):    "Is it just me, or is this confusing?"
#   NLIR   (37 src chars): 'is it just me or is this confusing'?
#   REAL OUTPUT:          "Is it just me, or is this confusing?"   (exact, comma added)
#
#   CLOSENESS: exact frame; `?` even inserts the natural comma before "or". The 64th ?
#   framing: "is it just me, or …" checks whether a reaction is SHARED — distinct from #66
#   overthinking (is my worry excessive) and #45 is-it-normal (is the situation typical):
#   this asks whether OTHERS see it the same way.
#
# Run:  ./examples/target-aur1-75-sharedexp.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "TARGET (33 chars):  Is it just me, or is this confusing?"
say "NLIR (37 src chars):  'is it just me or is this confusing'?"
echo -n "  => "; "$NLIR" -e "'is it just me or is this confusing'?" --quiet

say "64th ? framing: 'is it just me, or…' → is the reaction SHARED (vs #66 overthinking, #45 is-it-normal)."
