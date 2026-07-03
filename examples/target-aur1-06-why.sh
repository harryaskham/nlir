#!/usr/bin/env bash
# nlir-TARGET-golf · aur1 · #06 — "the why-question"
#
# Third question CLASS from my `?` lane (after how-do-I #03 and what-is #05): the
# diagnostic "why". You seed the symptom; `?` builds the "Why …?" around it. Same
# operator, and it reads the seed's shape to pick the right interrogative.
#
#   TARGET (35 chars):    "Why do my tests keep failing randomly?"
#   NLIR   (33 src chars): 'my tests keep failing randomly'?
#   REAL OUTPUT:          "Why do my tests keep failing randomly?"   (exact)
#
#   CLOSENESS: exact. The seed is just the symptom clause; `?` supplies "Why do
#   …?" — the frame you'd actually type when something's misbehaving. Across my
#   three ? entries the SAME sigil produced how-do-I / what-is / why with no hint
#   from me: it infers the question type from the phrasing.
#
# Run:  ./examples/target-aur1-06-why.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "TARGET (35 chars):  Why do my tests keep failing randomly?"
say "NLIR (33 src chars):  'my tests keep failing randomly'?"
echo -n "  => "; "$NLIR" -e "'my tests keep failing randomly'?" --quiet

say "Third ? class: how-do-I (#03) / what-is (#05) / why (#06) — ? infers the frame from the seed."
