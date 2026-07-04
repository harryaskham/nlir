#!/usr/bin/env bash
# nlir-TARGET-golf · aur1 · #58 — "the learning-order question" (Should I learn X or Y first?)
#
# The "should I learn X or Y first?" turn — asking which of two skills to start with,
# a sequencing decision. A "should i learn X or Y first" seed steers `?` to the "Should
# I learn X or Y first?" ordering frame.
#
#   TARGET (38 chars):    "Should I learn Python or JavaScript first?"
#   NLIR   (39 src chars): 'should i learn python or javascript first'?
#   REAL OUTPUT:          "Should I learn Python or JavaScript first?"   (exact)
#
#   CLOSENESS: exact. The 47th ? framing. `?` keeps the "should I learn X or Y first?"
#   sequencing frame and capitalises both names. Distinct from #08 "Should I …?" (a
#   single yes/no) and #56's disambig: this asks which to do FIRST — the ordering of two.
#
# Run:  ./examples/target-aur1-58-learnorder.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "TARGET (38 chars):  Should I learn Python or JavaScript first?"
say "NLIR (39 src chars):  'should i learn python or javascript first'?"
echo -n "  => "; "$NLIR" -e "'should i learn python or javascript first'?" --quiet

say "47th ? framing: 'should i learn X or Y first' → SEQUENCING two (vs #08 single yes/no, #56 disambig)."
