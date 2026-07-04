#!/usr/bin/env bash
# nlir-TARGET-golf · aur1 · #38 — "the when-to-use question" (When should I use X vs Y?)
#
# The "when should I use X versus Y?" turn — asking for the DECISION BOUNDARY
# between two tools (which situations favour each), not which is better overall.
# A "when to use X vs Y" seed steers `?` to the "When should I use X versus Y?" frame.
#
#   TARGET (~44 chars):   "When should I use a queue versus a database?"
#   NLIR   (36 src chars): 'when to use a queue vs a database'?
#   REAL OUTPUT (pronoun floats I/you): "When should I/you use a queue versus a database?"
#
#   CLOSENESS: exact frame; `?` expands "vs" → "versus" and adds "should I". The
#   27th ? framing: asks for the situational BOUNDARY between two options, distinct
#   from #32 "Is X or Y faster?" (a metric) and #37 "How do I choose …?" (general
#   criteria) — here specifically WHEN each applies.
#
# Run:  ./examples/target-aur1-38-whentouse.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "TARGET (~44 chars):  When should I use a queue versus a database?"
say "NLIR (36 src chars):  'when to use a queue vs a database'?"
echo -n "  => "; "$NLIR" -e "'when to use a queue vs a database'?" --quiet

say "27th ? framing: 'when to use X vs Y' → the situational BOUNDARY (vs #32 metric, #37 criteria)."
