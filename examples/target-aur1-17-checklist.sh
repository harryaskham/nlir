#!/usr/bin/env bash
# nlir-TARGET-golf · aur1 · #17 — "the three-part checklist question" (? ∘ &)
#
# A very common pi turn: one question covering a whole mini-workflow. `&` chains
# three task stems, `?` wraps the lot into a single "Can you X, Y, and Z?".
#
#   TARGET (~48 chars):  a three-step checklist question, e.g.
#     "Can you set up CI, run the tests, and deploy to staging?"
#   NLIR   (49 src chars): ('set up ci'&'run the tests'&'deploy to staging')?
#   REAL OUTPUT (auxiliary floats Can/Could run-to-run):
#     "Can you set up CI, run the tests, and deploy to staging?"
#     "Could you set up CI, run the tests, and deploy to staging?"
#
#   HOW IT NESTS: the variadic `&` folds three fragments into "set up ci and run
#   the tests and deploy to staging"; the postfix `?` then frames the whole chain
#   as one request-question, normalising "ci"→"CI" and inserting the serial
#   comma. Three bare steps → one grammatical checklist question. (Scales: add a
#   fourth `&` operand and the question grows a clause.)
#
# Run:  ./examples/target-aur1-17-checklist.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "TARGET (48 chars):  Can you set up CI, run the tests, and deploy to staging?"
say "NLIR (49 src chars):  ('set up ci'&'run the tests'&'deploy to staging')?"
echo -n "  => "; "$NLIR" -e "('set up ci'&'run the tests'&'deploy to staging')?" --quiet

say "& chains three steps, ? frames them as one checklist question — scales with each & operand."
