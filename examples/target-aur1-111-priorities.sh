#!/usr/bin/env bash
# nlir-TARGET-golf · aur1 · #111 🎯 100th ? SHAPE — "the priorities question" (What matters most here?)
#
# The 100th distinct ? framing — fittingly, the one that cuts through everything else. "What
# matters most here?" strips a tangled situation down to the single thing that actually counts,
# the priority that should drive the decision. A "what matters most here" seed steers `?` to
# that essence/priority frame.
#
#   TARGET (22 chars):    "What matters most here?"
#   NLIR   (24 src chars): 'what matters most here'?
#   REAL OUTPUT:          "What matters most here?"   (exact)
#
#   CLOSENESS: exact. The 100th ? framing 🎯. `?` keeps the "what matters most?" priority frame.
#   Distinct from #100 real-question (reframe the debate) and #89 leverage (highest-impact
#   action): this asks for the one thing that MATTERS most — the value to optimise for.
#
# One hundred question shapes, from one postfix `?`. The whole palette — what/why/how/when/who/
# which, worth-it/risk/reversibility/scalability/fit/opportunity — all the same operator, steered
# only by the seed text. `?` projects onto the information and asks it back.
#
# Run:  ./examples/target-aur1-111-priorities.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "🎯 TARGET (22 chars):  What matters most here?   — the 100th distinct ? shape"
say "NLIR (24 src chars):  'what matters most here'?"
echo -n "  => "; "$NLIR" -e "'what matters most here'?" --quiet

say "🎯 100th ? framing: 'what matters most here' → strip to the single thing that counts / the priority to optimise for (vs #100 real-question, #89 leverage). One hundred question shapes from one postfix ?."
