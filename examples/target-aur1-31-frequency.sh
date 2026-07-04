#!/usr/bin/env bash
# nlir-TARGET-golf · aur1 · #31 — "the frequency question" (How often should I…?)
#
# The "how often should I X?" turn — asking for a cadence/interval, not a quantity
# or a duration. A "how often should i X" seed steers `?` to the "How often should
# I …?" recurrence frame.
#
#   TARGET (~34 chars):   a frequency question, e.g. "How often should I rotate API keys?"
#   NLIR   (36 src chars): 'how often should i rotate api keys'?
#   REAL OUTPUT (pronoun floats I/you): "How often should I/you rotate API keys?"
#
#   CLOSENESS: exact. The 20th ? framing. `?` keeps the "how often" cadence frame
#   and capitalises the acronym. Distinct from #09 "How much …?" (quantity) and
#   #19 "How long …?" (duration): "how often" asks for a RECURRENCE interval — the
#   maintenance-cadence question.
#
# Run:  ./examples/target-aur1-31-frequency.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "TARGET (34 chars):  How often should I rotate API keys?"
say "NLIR (36 src chars):  'how often should i rotate api keys'?"
echo -n "  => "; "$NLIR" -e "'how often should i rotate api keys'?" --quiet

say "20th ? framing: 'how often should i X' → recurrence cadence (vs #09 quantity, #19 duration)."
