#!/usr/bin/env bash
# nlir-TARGET-golf · aur1 · #74 — "the scalability question" (Does this scale?)
#
# The "does this scale?" turn — the punchy check on whether an approach holds up as load /
# size grows, the shortest form of an engineering worry. A "does this scale" seed steers `?`
# to the "Does this scale?" growth-check frame.
#
#   TARGET (16 chars):    "Does this scale?"
#   NLIR   (18 src chars): 'does this scale'?
#   REAL OUTPUT:          "Does this scale?"   (exact)
#
#   CLOSENESS: exact — a tiny 18-char source for a complete engineering question. The 63rd
#   ? framing. `?` keeps the "does this scale?" growth-check. Distinct from #22 is-X-Y-faster
#   (raw speed) and #27 worth-it (value): this asks whether it HOLDS UP as things grow.
#
# Run:  ./examples/target-aur1-74-scalability.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "TARGET (16 chars):  Does this scale?"
say "NLIR (18 src chars):  'does this scale'?"
echo -n "  => "; "$NLIR" -e "'does this scale'?" --quiet

say "63rd ? framing: 'does this scale' → holds up as it GROWS (vs #22 raw-speed, #27 worth-it). 18 chars → a full question."
