#!/usr/bin/env bash
# nlir-TARGET-golf · aur1 · #08 — "the decision question"
#
# Fourth question CLASS from my `?` lane (after how-do-I #03, what-is #05, why
# #06): the "should I X or Y?" DECISION you type when you're choosing between two
# options. You seed the two options with an "or"; `?` builds the deliberating
# frame.
#
#   TARGET (36 chars):    "Should I use REST or GraphQL for my API?"
#   NLIR   (33 src chars): 'use REST or GraphQL for my API'?
#   REAL OUTPUT:          "Should I use REST or GraphQL for my API?"   (exact)
#
#   CLOSENESS: exact. The seed carries the two options and the context; `?`
#   supplies the "Should I …?" deliberation frame. My four ? entries now span
#   how-do-I / what-is / why / should-I — one operator, four interrogative moods,
#   each inferred purely from the seed's shape (a verb phrase, a "difference
#   between", a symptom, an "X or Y").
#
# Run:  ./examples/target-aur1-08-decision.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "TARGET (36 chars):  Should I use REST or GraphQL for my API?"
say "NLIR (33 src chars):  'use REST or GraphQL for my API'?"
echo -n "  => "; "$NLIR" -e "'use REST or GraphQL for my API'?" --quiet

say "Fourth ? mood: how-do-I / what-is / why / should-I — inferred from the seed's shape alone."
