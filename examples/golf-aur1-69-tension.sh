#!/usr/bin/env bash
# nlir-golf · aur1 · #69 — "the tension-namer" (~(A&B) on OPPOSING views states the disagreement)
#
# I went looking for a mediator and found a namer. The polymorphic `~(a&b)` has three modes
# depending on how its operands relate: fuse two COMPATIBLE points (#15 merge), diff a
# before/after (#33 arc), and — the third mode, shown here — take two OPPOSING views and
# state the TENSION between them. I expected `~(A & B)` to synthesise a compromise; instead
# it does the honest thing nlir always does: it FRAMES, it doesn't adjudicate.
#
#   THE TENSION-NAMER   ~ ( A & B )
#     A "we should ship fast and iterate in production"
#     B "we should slow down and nail quality before shipping"
#     ~(A & B) → "The team is torn between shipping fast and iterating versus slowing down
#                 to ensure quality first."
#
# Not a verdict, not a bridge — a crisp statement of the disagreement, the thing a
# facilitator writes on the whiteboard BEFORE the discussion. That "torn between X versus Y"
# shape is the dialectic mode, and it completes the polymorphic-`~(a&b)` trio: compatible →
# fuse, sequential → diff, opposed → name the tension. (nlir transforms and frames; it never
# reasons forward to a resolution — same honest limit as my rejected "consult".)
#
# Run:  ./examples/golf-aur1-69-tension.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
A='we should ship fast and iterate in production'
B='we should slow down and nail quality before shipping'

say "THE TENSION-NAMER  ~(A & B)  — two OPPOSING views → a crisp statement of the disagreement"
echo   "  A: $A"
echo   "  B: $B"
echo -n "  ~(A & B) => "; "$NLIR" -e "~('$A' & '$B')" --quiet | fold -s -w 82 | sed '2,$s/^/       /'

say "The 3rd mode of ~(a&b): compatible→fuse (#15), sequential→diff (#33), opposed→name the tension. It frames, never adjudicates."
