#!/usr/bin/env bash
# nlir-TARGET-golf · aur1 · #36 — "the caveat question" (What are the downsides of…?)
#
# The "what are the downsides of X?" turn — asking for the drawbacks/risks of a
# choice, the flip side of the hype. A "downsides of X-ing" seed steers `?` to the
# "What are the downsides of …?" caveat frame.
#
#   TARGET (45 chars):    "What are the downsides of going serverless?"
#   NLIR   (33 src chars): 'downsides of going serverless'?
#   REAL OUTPUT:          "What are the downsides of going serverless?"   (exact)
#
#   CLOSENESS: exact. The 25th ? framing. `?` reads "downsides of …" as a drawbacks
#   question and builds "What are the downsides of …?". Distinct from #34 "What's
#   wrong with X?" (critique of a specific thing) and #31 pro/con: this asks for the
#   general trade-off cost of an approach — the due-diligence turn.
#
# Run:  ./examples/target-aur1-36-caveat.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "TARGET (45 chars):  What are the downsides of going serverless?"
say "NLIR (33 src chars):  'downsides of going serverless'?"
echo -n "  => "; "$NLIR" -e "'downsides of going serverless'?" --quiet

say "25th ? framing: 'downsides of X' → a caveat/due-diligence question (vs #34 critique, #31 pro/con)."
