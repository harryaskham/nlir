#!/usr/bin/env bash
# nlir-TARGET-golf · aur1 · #03 — "statement → How-question"
#
# My reconstruction lane is `?` (questionify): the most common pi user turn isn't
# a statement, it's a QUESTION. `?` is a decompressor from a terse topic phrase
# into a natural, well-formed question — you seed WHAT you're stuck on, `?` adds
# the "How do I…?" scaffolding.
#
#   TARGET (34 chars):   "How do I fix a git merge conflict?"
#   NLIR   (27 src chars): 'fix a git merge conflict'?
#   REAL OUTPUT:         "How do I fix a git merge conflict?"   (exact)
#
#   CLOSENESS: character-for-character exact. `?` reliably turns an imperative
#   topic phrase into the "How do I …?" question a user would actually type. The
#   seed carries only the verb+object; the interrogative frame is generated.
#
# Distinct from @ (msm0, register), > / : (aur-2, length): ? reconstructs
# QUESTION-SHAPED turns — a different realistic-pi turn class.
#
# Run:  ./examples/target-aur1-03-question.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "TARGET (34 chars):  How do I fix a git merge conflict?"
say "NLIR (27 src chars):  'fix a git merge conflict'?"
echo -n "  => "; "$NLIR" -e "'fix a git merge conflict'?" --quiet

say "? reconstructs QUESTION-shaped user turns — seed the verb+object, get the How-frame free."
