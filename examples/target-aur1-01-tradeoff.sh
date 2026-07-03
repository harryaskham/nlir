#!/usr/bin/env bash
# nlir-TARGET-golf · aur1 · #01 — "compression vs fidelity"
#
# REVERSE game (Harry): fix a realistic chat-style sentence, then find the
# SHORTEST nlir whose output is CLOSEST to it. nlir's register ops (@ : > <) are
# lossy semantic (de)compressors: a terse seed + an inflating op regenerates a
# full sentence. This first entry shows the core TENSION every target-golfer
# fights — compression vs fidelity.
#
#   TARGET (72 chars):
#     "Remote work boosts productivity but can make team collaboration harder."
#
#   A) HIGH COMPRESSION   >'remote work: +productivity, -collaboration'   (43 src chars)
#      `>` expands a keyword seed — semantically dead-on but OVERSHOOTS to a
#      full paragraph. Great ratio, poor length-fidelity to a one-liner target.
#
#   B) HIGH FIDELITY      @'remote work boosts productivity but hurts collaboration'  (56 src chars)
#      `@` formalises a near-complete seed — tight one-line match, but low
#      compression (the seed already carries most of the sentence).
#
# The sport: push the seed SHORTER while keeping the output CLOSE. `>` wins ratio,
# `@`/`:` win fidelity; a paragraph target favours `>`, a one-liner favours `@`.
#
# Run:  ./examples/target-aur1-01-tradeoff.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
TARGET="Remote work boosts productivity but can make team collaboration harder."

say "TARGET: $TARGET"

say "A) HIGH COMPRESSION  >'remote work: +productivity, -collaboration'  (43 src chars)"
echo -n "   => "; "$NLIR" -e ">'remote work: +productivity, -collaboration'" --quiet

say "B) HIGH FIDELITY  @'remote work boosts productivity but hurts collaboration'  (56 src chars)"
echo -n "   => "; "$NLIR" -e "@'remote work boosts productivity but hurts collaboration'" --quiet

say "Compression vs fidelity — the whole target-golf game in one target."
