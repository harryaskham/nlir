#!/usr/bin/env bash
# nlir-TARGET-golf · aur1 · #37 — "the selection-method question" (How do I choose between…?)
#
# The "how do I choose between X and Y?" turn — asking for the DECISION CRITERIA,
# not which one wins. A "how to choose between X and Y" seed steers `?` to the
# "How do I choose between X and Y?" method frame.
#
#   TARGET (~40 chars):   "How do I choose between REST and GraphQL?"
#   NLIR   (38 src chars): 'how to choose between rest and graphql'?
#   REAL OUTPUT (pronoun floats I/you): "How do I/you choose between REST and GraphQL?"
#
#   CLOSENESS: exact frame; capitalises both acronyms; "I"/"you" floats run-to-run.
#   The 26th ? framing: asks for the CRITERIA to decide, distinct from #32 "Is X or
#   Y faster?" (which one wins a metric) and #20 "Which X?" (pick one) — here: teach
#   me how to make the call myself.
#
# Run:  ./examples/target-aur1-37-selection.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "TARGET (~40 chars):  How do I choose between REST and GraphQL?"
say "NLIR (38 src chars):  'how to choose between rest and graphql'?"
echo -n "  => "; "$NLIR" -e "'how to choose between rest and graphql'?" --quiet

say "26th ? framing: 'how to choose between X and Y' → DECISION-CRITERIA (vs #32 which-wins, #20 which)."
