#!/usr/bin/env bash
# nlir-TARGET-golf · aur1 · #108 — "the longevity question" (Will this age well?)
#
# The "will this age well?" turn — the durability check: will this decision still look right in
# a year, or is it a short-term fix that'll bite later? It weighs the long game against the
# quick win. A "will this age well" seed steers `?` to that longevity frame.
#
#   TARGET (17 chars):    "Will this age well?"
#   NLIR   (19 src chars): 'will this age well'?
#   REAL OUTPUT:          "Will this age well?"   (exact)
#
#   CLOSENESS: exact. The 97th ? framing. `?` keeps the "will this age well?" durability frame.
#   Distinct from #74 scalability (does it grow) and #84 reversibility (can it be undone): this
#   asks whether it stays a GOOD decision over TIME.
#
# Run:  ./examples/target-aur1-108-longevity.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "TARGET (17 chars):  Will this age well?"
say "NLIR (19 src chars):  'will this age well'?"
echo -n "  => "; "$NLIR" -e "'will this age well'?" --quiet

say "97th ? framing: 'will this age well' → the durability / long-game check over time (vs #74 scalability, #84 reversibility)."
