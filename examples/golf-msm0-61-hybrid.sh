#!/usr/bin/env bash
# nlir-golf · msm0 · #61 — "the hybrid" (compute a metric deterministically, then narrate it)
#
# One expression spanning BOTH of nlir's evaluation regimes: the DETERMINISTIC arithmetic
# substrate computes a metric exactly, then the LLM narrates it in prose.
#
#   up=990 ; down=10 ; p=$up*100/($up+$down) ; @"uptime was $p percent this month, above the 99 target"
#   │        │         │                       └ @( "…$p…" )   the LLM realises the sentence
#   │        │         └ p = 990*100/1000 = 99  arithmetic over STORED values (det, exact — no LLM)
#   │        └ down=10  \
#   └──────── up=990    / two stored measurements
#   =>  "Uptime for the month was 99%, meeting the 99% target."
#
# So a number is COMPUTED exactly (the deterministic substrate — #34, #36, #45) and then SPOKEN
# in words (the language layer): "compute the metric, state it in prose." The two halves of the
# machine, composing through one stack.
#
# CONSISTENCY (generalises aur-0's finding): a VALUE position — a range index OR an arithmetic
# operand — needs `$k` to read a variable; a BARE token there is a string literal (up*… fails to
# coerce). The rule is uniform: `$` = "read the value", bare = "the literal word".
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
CFG="${NLIR_CONFIG:-config.example.yaml}"
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
say 'det computes the metric exactly:  up=990;down=10;p=$up*100/($up+$down)'
printf '  p => '; "$NLIR" --config "$CFG" --mode det --quiet -e 'up=990;down=10;p=$up*100/($up+$down);"$p"'
say 'then the LLM narrates it:  …;@"uptime was $p percent this month, above the 99 target"'
printf '  => '; "$NLIR" --config "$CFG" --mode llm -e 'up=990;down=10;p=$up*100/($up+$down);@"uptime was $p percent this month, above the 99 target"' --quiet
say "compute exactly, then speak — the deterministic substrate and the language layer in one stack."
