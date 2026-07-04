#!/usr/bin/env bash
# nlir-golf · msm0 · #58 — "the fixed point" (~ converges: re-summarising bottoms out)
#
# The summary operator ~ CONVERGES to a fixed point. Once you've distilled to the core
# facts, a further ~ has nothing left to drop — it just paraphrases the same content. So
# ~~x ≈ ~x: the "already-minimal" summary is a FIXED POINT.
#
#   ~x    => "…the budget overrun, hiring freeze, and plans to ship the mobile app by Q3
#             despite reduced headcount."          (three core facts)
#   ~~x   => the same three facts, barely shorter
#   ~~~x  => the same three facts, just reworded    (information content has bottomed out)
#
# This is the exact COMPLEMENT of #57's involution: ! OSCILLATES (period 2, never settles),
# while ~ (and @, which saturates the register) CONVERGE to a fixed point. Together they
# complete the repetition-dynamics picture — some operators flip back and forth, some settle
# to a stable point, and ? projects on the very first hit (P²=P, aur-1). The stack walks
# ~~~x as three summarise-nodes over one operand, but the meaning stops moving after the first.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
CFG="${NLIR_CONFIG:-config.example.yaml}"
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi

B="the meeting covered three topics: the budget overrun, the hiring freeze, and the plan to ship the mobile app by Q3 despite the reduced headcount"
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
run() { printf '  %-6s => ' "$1"; "$NLIR" --config "$CFG" --mode llm -e "$1'$B'" --quiet; }
say "~ converges — after the first distillation the core facts survive, length bottoms out:"
run '~'
run '~~'
run '~~~'
say "a FIXED POINT — the complement of #57's involution: ! oscillates, ~ (and @) settle."
