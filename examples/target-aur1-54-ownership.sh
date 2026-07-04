#!/usr/bin/env bash
# nlir-TARGET-golf · aur1 · #54 — "the ownership question" (Who should own X?)
#
# The "who should own X?" turn — asking which party is responsible for something,
# often between two candidates. A "should X or Y own Z" seed steers `?` to a "Who
# should own Z — X or Y?" ownership frame.
#
#   TARGET (~46 chars):   "Who should own validation — frontend or backend?"
#   NLIR   (39 src chars): 'should frontend or backend own validation'?
#   REAL OUTPUT:          "Who should own validation — frontend or backend?"  (≈ exact; reframed)
#
#   CLOSENESS: exact meaning; `?` recognises the responsibility question and reframes
#   "should X or Y own Z" into the cleaner "Who should own Z — X or Y?". The 43rd ?
#   framing: RESPONSIBILITY/ownership — distinct from #13 "Who …?" (identity) and #15's
#   disambig (which one): who's accountable for this.
#
# Run:  ./examples/target-aur1-54-ownership.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "TARGET (~46 chars):  Who should own validation — frontend or backend?"
say "NLIR (39 src chars):  'should frontend or backend own validation'?"
echo -n "  => "; "$NLIR" -e "'should frontend or backend own validation'?" --quiet

say "43rd ? framing: 'should X or Y own Z' → RESPONSIBILITY/ownership (vs #13 identity, #15 which-one)."
