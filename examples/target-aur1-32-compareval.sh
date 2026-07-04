#!/usr/bin/env bash
# nlir-TARGET-golf · aur1 · #32 — "the comparison-eval question" (Is X or Y more…?)
#
# The "is X or Y faster/better?" turn — asking which of two options wins on an
# ATTRIBUTE, not merely which one it is. A "is X or Y <attr> for Z" seed steers `?`
# to the "Is X or Y <attr> for Z?" comparative-evaluation frame.
#
#   TARGET (37 chars):    "Is Redis or Postgres faster for caching?"
#   NLIR   (39 src chars): 'is redis or postgres faster for caching'?
#   REAL OUTPUT:          "Is Redis or Postgres faster for caching?"   (exact)
#
#   CLOSENESS: exact. The 21st ? framing. `?` keeps the comparative "faster" and
#   the "for caching" scope, capitalising both proper nouns. Distinct from #15
#   disambig ("Is it X or Y?" = pure identification): here the comparative
#   adjective makes it an EVALUATION — which option wins on a metric.
#
# Run:  ./examples/target-aur1-32-compareval.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "TARGET (37 chars):  Is Redis or Postgres faster for caching?"
say "NLIR (39 src chars):  'is redis or postgres faster for caching'?"
echo -n "  => "; "$NLIR" -e "'is redis or postgres faster for caching'?" --quiet

say "21st ? framing: comparative adjective → an EVALUATION (which wins on a metric) vs #15 pure id."
