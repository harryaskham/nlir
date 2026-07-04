#!/usr/bin/env bash
# nlir-TARGET-golf · aur1 · #88 — "the problem-framing question" (Am I solving the right problem?)
#
# The "am I solving the right problem?" turn — the step-back check on whether you're aimed at
# the right target at all, before optimising the solution. A first-person "am i solving the
# right problem" seed steers `?` to that framing check.
#
#   TARGET (28 chars):    "Am I solving the right problem?"
#   NLIR   (30 src chars): 'am i solving the right problem'?
#   REAL OUTPUT:          "Am I solving the right problem?"   (exact)
#
#   CLOSENESS: exact. The 77th ? framing. `?` keeps the "right problem?" framing-check.
#   Distinct from #85 simpler-way (a better solution) and #84 reinventing-wheel (does it
#   exist): this questions the PROBLEM itself — are you even aimed at the right thing?
#
# Run:  ./examples/target-aur1-88-framing.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "TARGET (28 chars):  Am I solving the right problem?"
say "NLIR (30 src chars):  'am i solving the right problem'?"
echo -n "  => "; "$NLIR" -e "'am i solving the right problem'?" --quiet

say "77th ? framing: 'am i solving the right problem' → question the PROBLEM itself (vs #85 simpler-way, #84 reinventing-wheel)."
